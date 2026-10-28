# 06 · Batería y arranque

## Batería segura

`koreader/plugins/glohd.koplugin/main.lua`. KOReader, a diferencia de Nickel, no apagaba el Kobo con batería crítica: el kernel solo reporta capacidad 0 (`critical_low_flag` en `ricoh619-battery.c`) y el equipo seguía hasta que el PMU cortaba la corriente con la memoria montada. Es la causa más probable de la pantalla de "restaurar de fábrica" (no se ha visto ocurrir en vivo).

- Despierto: revisa cada 60 s y apaga limpio a 3% o 3500 mV (dos lecturas seguidas), lo que llegue primero.
- Dormido: alarma RTC cada 4 h; apaga limpio a 5% o 3600 mV.
- Umbrales con margen sobre lo que dice el kernel: el medidor apunta 0% a 3300 mV y el PMU da alarma a 3400 mV (`board-mx6sl_ntx.c`). La batería es de 2015, por eso no se confía solo en el porcentaje.
- Registro en `/mnt/onboard/.adds/usbnet/bateria.csv`: porcentaje, voltaje y cargador cada 10 min despierto, en cada alarma y al dormir y despertar; en cada arranque, el `POWER off history` del PMU (`0x10` = reinicio normal). Sirve para ajustar los umbrales con la curva real.

## Arranque (`sistema/rcS`)

- Si `dosfsck` no deja limpia la memoria pero esta monta, arranca normal y anota en `.kobo/arranque-avisos.log`. Restaurar de fábrica solo si la memoria no monta o falta `pickel`.
- Se quitó el "power fix" de `state-extended`.
- Antes de instalarlo, guarda el original en la Kobo (por ejemplo `/etc/init.d/rcS.antes`). Verificado en arranques completos.

Cómo instalarlo: ver [01 · KOReader desde cero](01-koreader-desde-cero.md).

## Lo que falta

- Ajustar los umbrales de batería con una o dos descargas completas registradas en `bateria.csv`. Si haces una, compártela en un issue.
