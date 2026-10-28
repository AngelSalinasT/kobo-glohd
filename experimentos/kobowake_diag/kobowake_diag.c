/*
 * kobowake_diag — diagnóstico de SOLO LECTURA del despertar en Kobo Glo HD (i.MX6SL).
 * Imprime en dmesg los registros de GPIO5 (botón = GPIO5_8, cubierta = GPIO5_12),
 * del GPC (fuentes de despertar) y de los pads, al cargar, justo antes de dormir
 * y justo al despertar (antes de que se atiendan las interrupciones).
 * No escribe ningún registro.
 */
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/io.h>
#include <linux/syscore_ops.h>

#define GPIO5_PHYS   0x020AC000
#define GPC_PHYS     0x020DC000
#define IOMUXC_PHYS  0x020E0000

static void __iomem *gpio5, *gpc, *iomuxc;

static void dump(const char *when)
{
	u32 dr = readl(gpio5 + 0x00), psr = readl(gpio5 + 0x08);
	u32 icr1 = readl(gpio5 + 0x0C), imr = readl(gpio5 + 0x14);
	u32 isr = readl(gpio5 + 0x18), edge = readl(gpio5 + 0x1C);

	printk(KERN_INFO "kobowake[%s] GPIO5 DR=%08x PSR=%08x ICR1=%08x IMR=%08x ISR=%08x EDGE=%08x\n",
	       when, dr, psr, icr1, imr, isr, edge);
	printk(KERN_INFO "kobowake[%s] boton(5_8): nivel=%u imr=%u isr=%u icr=%u | cubierta(5_12): nivel=%u imr=%u isr=%u icr=%u\n",
	       when, (psr >> 8) & 1, (imr >> 8) & 1, (isr >> 8) & 1, (icr1 >> 16) & 3,
	       (psr >> 12) & 1, (imr >> 12) & 1, (isr >> 12) & 1, (icr1 >> 24) & 3);
	printk(KERN_INFO "kobowake[%s] GPC IMR=%08x %08x %08x %08x ISR=%08x %08x %08x %08x\n",
	       when, readl(gpc + 0x08), readl(gpc + 0x0C), readl(gpc + 0x10), readl(gpc + 0x14),
	       readl(gpc + 0x18), readl(gpc + 0x1C), readl(gpc + 0x20), readl(gpc + 0x24));
	printk(KERN_INFO "kobowake[%s] PAD boton mux=%08x ctl=%08x | cubierta mux=%08x ctl=%08x\n",
	       when, readl(iomuxc + 0x238), readl(iomuxc + 0x540),
	       readl(iomuxc + 0x244), readl(iomuxc + 0x54C));
}

static int kw_suspend(void) { dump("antes-de-dormir"); return 0; }
static void kw_resume(void) { dump("al-despertar"); }

static struct syscore_ops kw_ops = {
	.suspend = kw_suspend,
	.resume  = kw_resume,
};

static int __init kw_init(void)
{
	gpio5 = ioremap(GPIO5_PHYS, 0x20);
	gpc = ioremap(GPC_PHYS, 0x30);
	iomuxc = ioremap(IOMUXC_PHYS, 0x1000);
	if (!gpio5 || !gpc || !iomuxc)
		goto fail;
	dump("carga");
	register_syscore_ops(&kw_ops);
	return 0;
fail:
	if (gpio5) iounmap(gpio5);
	if (gpc) iounmap(gpc);
	if (iomuxc) iounmap(iomuxc);
	return -ENOMEM;
}

static void __exit kw_exit(void)
{
	unregister_syscore_ops(&kw_ops);
	iounmap(gpio5); iounmap(gpc); iounmap(iomuxc);
}

module_init(kw_init);
module_exit(kw_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Diagnóstico de despertar Kobo Glo HD (solo lectura)");
