-- defaults.custom.lua
-- Solo cache: el default es 512MB (igual a la RAM total del Glo HD). Causa OOM.
-- Cambios mínimos y testeados. Para revertir: poner "return {}".
return {
    DGLOBAL_CACHE_SIZE_MINIMUM = 1024 * 1024 * 4,
    DGLOBAL_CACHE_SIZE_MAXIMUM = 1024 * 1024 * 32,
    DGLOBAL_CACHE_FREE_PROPORTION = 0.2,
    DHINTCOUNT = 1,  -- pre-render de la página siguiente (default de KOReader); 0 lo apagaba
    -- Borde izquierdo para el brillo: 1/4 de pantalla (antes 1/8). Medido: 4 de 9
    -- intentos empezaron entre x=135 y x=222, fuera de la franja de 134 px.
    DSWIPE_ZONE_LEFT_EDGE = { x = 0, y = 0, w = 1/4, h = 1 },
}
