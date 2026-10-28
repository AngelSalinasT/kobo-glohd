/*
 * kobowake — el botón de encendido despierta a la Kobo Glo HD (i.MX6SL, kernel 3.0.35 de Kobo).
 *
 * Causa (medida con kobowake_diag): gpio-keys pide "ambos flancos" para el botón
 * (GPIO5_8) y el driver mxc lo emula con disparo por NIVEL. Con el SoC dormido ese disparo
 * nunca se registra (ISR bit 8 = 0); el táctil, configurado por FLANCO, sí despierta.
 *
 * Arreglo:
 *  - Antes de dormir (PM notifier): marcar el IRQ del botón como fuente de despertar.
 *  - Justo antes de dormir (syscore): cambiar GPIO5_8 a flanco de bajada y limpiar su ISR.
 *  - Al despertar (syscore): si el ISR del botón quedó en 1, fue el botón; restaurar la
 *    configuración original. Si el botón ya se soltó, enviar KEY_POWER (presionar+soltar)
 *    por gpio-keys para que KOReader lo trate como despertar legítimo; si sigue presionado,
 *    o si gpio-keys reporta una pulsación real en los siguientes 500 ms, no se inyecta
 *    (evita pulsaciones dobles, p. ej. al salir de la espera ligera de autostandby).
 * Quitar: rmmod kobowake (o reiniciar).
 */
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/io.h>
#include <linux/gpio.h>
#include <linux/interrupt.h>
#include <linux/input.h>
#include <linux/suspend.h>
#include <linux/syscore_ops.h>
#include <linux/workqueue.h>
#include <linux/slab.h>

#define GPIO5_PHYS 0x020AC000
#define REG_PSR    0x08
#define REG_ICR1   0x0C
#define REG_ISR    0x18
#define BTN_BIT    8                       /* GPIO5_8 */
#define BTN_GPIO   (4 * 32 + BTN_BIT)      /* IMX_GPIO_NR(5, 8) = 136 */
#define ICR_SHIFT  (BTN_BIT * 2)
#define ICR_FALL   0x3

static int verbose = 1;
module_param(verbose, int, 0644);
MODULE_PARM_DESC(verbose, "1 = registrar en dmesg cada dormir/despertar");

static void __iomem *gpio5;
static u32 saved_icr;
static int armed, woke_by_button, btn_irq;
static int seen_real_press, injecting;
static unsigned long wakes;
static struct input_handle *power_handle;

/* ---------- inyección de KEY_POWER por gpio-keys ---------- */
static void inject_power(struct work_struct *w)
{
	struct input_dev *dev = power_handle ? power_handle->dev : NULL;

	if (!dev)
		return;
	if (seen_real_press) {
		if (verbose)
			printk(KERN_INFO "kobowake: gpio-keys ya reportó el botón, no se inyecta\n");
		return;
	}
	injecting = 1;
	input_event(dev, EV_KEY, KEY_POWER, 1);
	input_sync(dev);
	input_event(dev, EV_KEY, KEY_POWER, 0);
	input_sync(dev);
	injecting = 0;
	if (verbose)
		printk(KERN_INFO "kobowake: despertó por el botón (#%lu), KEY_POWER enviado\n", wakes);
}
static DECLARE_DELAYED_WORK(inject_work, inject_power);

static int kw_connect(struct input_handler *h, struct input_dev *dev,
		      const struct input_device_id *id)
{
	struct input_handle *handle;
	int err;

	if (power_handle || strcmp(dev->name, "gpio-keys"))
		return -ENODEV;
	handle = kzalloc(sizeof(*handle), GFP_KERNEL);
	if (!handle)
		return -ENOMEM;
	handle->dev = dev;
	handle->handler = h;
	handle->name = "kobowake";
	err = input_register_handle(handle);
	if (err) {
		kfree(handle);
		return err;
	}
	power_handle = handle;
	return 0;
}

static void kw_event(struct input_handle *handle, unsigned int type,
		     unsigned int code, int value)
{
	if (type == EV_KEY && code == KEY_POWER && value == 1 && !injecting)
		seen_real_press = 1;
}

static void kw_disconnect(struct input_handle *handle)
{
	if (handle == power_handle)
		power_handle = NULL;
	input_unregister_handle(handle);
	kfree(handle);
}

static const struct input_device_id kw_ids[] = {
	{ .flags = INPUT_DEVICE_ID_MATCH_EVBIT | INPUT_DEVICE_ID_MATCH_KEYBIT,
	  .evbit = { BIT_MASK(EV_KEY) }, .keybit = { [BIT_WORD(KEY_POWER)] = BIT_MASK(KEY_POWER) } },
	{ },
};

static struct input_handler kw_handler = {
	.event = kw_event,
	.connect = kw_connect,
	.disconnect = kw_disconnect,
	.name = "kobowake",
	.id_table = kw_ids,
};

/* ---------- PM: armar el IRQ del botón como fuente de despertar ---------- */
static int kw_pm(struct notifier_block *nb, unsigned long ev, void *unused)
{
	if (ev == PM_SUSPEND_PREPARE && !armed) {
		armed = !enable_irq_wake(btn_irq);
	} else if (ev == PM_POST_SUSPEND && armed) {
		disable_irq_wake(btn_irq);
		armed = 0;
	}
	return NOTIFY_DONE;
}
static struct notifier_block kw_nb = { .notifier_call = kw_pm };

/* ---------- syscore: flanco de bajada sólo mientras duerme ---------- */
static int kw_suspend(void)
{
	u32 icr = readl(gpio5 + REG_ICR1);

	saved_icr = (icr >> ICR_SHIFT) & 3;
	icr = (icr & ~(3 << ICR_SHIFT)) | (ICR_FALL << ICR_SHIFT);
	writel(icr, gpio5 + REG_ICR1);
	writel(1 << BTN_BIT, gpio5 + REG_ISR);      /* w1c: limpiar pendientes */
	woke_by_button = 0;
	return 0;
}

static void kw_resume(void)
{
	u32 icr;

	if (readl(gpio5 + REG_ISR) & (1 << BTN_BIT)) {
		woke_by_button = 1;
		wakes++;
		writel(1 << BTN_BIT, gpio5 + REG_ISR);
	}
	icr = readl(gpio5 + REG_ICR1);
	icr = (icr & ~(3 << ICR_SHIFT)) | (saved_icr << ICR_SHIFT);
	writel(icr, gpio5 + REG_ICR1);

	/*
	 * Si el botón sigue presionado (nivel 0, activo en bajo), el disparo por nivel que se
	 * acaba de restaurar hará que gpio-keys reporte la pulsación por sí solo: no inyectar.
	 * Si ya se soltó, esa pulsación se perdió y se inyecta (salvo que llegue una real antes).
	 */
	seen_real_press = 0;
	if (woke_by_button && (readl(gpio5 + REG_PSR) & (1 << BTN_BIT)))
		schedule_delayed_work(&inject_work, msecs_to_jiffies(500));
}

static struct syscore_ops kw_ops = { .suspend = kw_suspend, .resume = kw_resume };

static int __init kw_init(void)
{
	int err;

	gpio5 = ioremap(GPIO5_PHYS, 0x20);
	if (!gpio5)
		return -ENOMEM;
	btn_irq = gpio_to_irq(BTN_GPIO);
	err = input_register_handler(&kw_handler);
	if (err)
		goto out_unmap;
	if (!power_handle) {
		printk(KERN_ERR "kobowake: no encontré gpio-keys\n");
		err = -ENODEV;
		goto out_handler;
	}
	err = register_pm_notifier(&kw_nb);
	if (err)
		goto out_handler;
	register_syscore_ops(&kw_ops);
	printk(KERN_INFO "kobowake: listo (irq %d, gpio %d)\n", btn_irq, BTN_GPIO);
	return 0;

out_handler:
	input_unregister_handler(&kw_handler);
out_unmap:
	iounmap(gpio5);
	return err;
}

static void __exit kw_exit(void)
{
	unregister_syscore_ops(&kw_ops);
	unregister_pm_notifier(&kw_nb);
	cancel_delayed_work_sync(&inject_work);
	if (armed)
		disable_irq_wake(btn_irq);
	input_unregister_handler(&kw_handler);
	iounmap(gpio5);
}

module_init(kw_init);
module_exit(kw_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Botón de encendido despierta Kobo Glo HD");
