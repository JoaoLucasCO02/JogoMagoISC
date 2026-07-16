.data
.include "vilao.data"
.include "eyeofrah.data"

.eqv OGRE_INTERVALO 5
.eqv OGRE_SPAWN_INTERVALO 60
.eqv OLHO_INTERVALO 3
.eqv OGRE_DIST_MIN 80
.eqv META_INIMIGOS_FASE 20
.eqv MAX_OGROS_FASE2 1
.eqv MAX_OLHOS_FASE2 4
.eqv TIPO_OGRO 1
.eqv TIPO_OLHO 2

inimigos_mortos: .word 0
spawn_timer: .word 0

.text

# Fase 1 (nivel 0): um ogro e quatro olhos. Fase 2 (nivel 1): dois ogros.
# Fase 3 fica reservada ao chefe e nao cria inimigos comuns.
spawn_inimigos:
    addi sp, sp, -4
    sw ra, 0(sp)
    la t0, nivel_atual
    lw t0, 0(t0)
    beqz t0, spawn_fase1
    li t1, 1
    beq t0, t1, spawn_fase2
    j spawn_inimigos_fim
spawn_fase1:
    la a0, inimigos
    li a1, TIPO_OGRO
    jal spawn_tipo
    la a0, inimigos
    addi a0, a0, TAM_INIMIGO
    li a1, TIPO_OLHO
    jal spawn_tipo
    la a0, inimigos
    addi a0, a0, 48
    li a1, TIPO_OLHO
    jal spawn_tipo
    la a0, inimigos
    addi a0, a0, 72
    li a1, TIPO_OLHO
    jal spawn_tipo
    la a0, inimigos
    addi a0, a0, 96
    li a1, TIPO_OLHO
    jal spawn_tipo
    j spawn_inimigos_fim
spawn_fase2:
    la a0, inimigos
    li a1, TIPO_OGRO
    jal spawn_tipo
    la a0, inimigos
    addi a0, a0, TAM_INIMIGO
    li a1, TIPO_OGRO
    jal spawn_tipo
spawn_inimigos_fim:
    la t2, nivel_atual
    lw t2, 0(t2)
    li t3, 1
    beq t2, t3, spawn_timer_ogro    # fase 2 (so ogros): timer rapido de ogro
    li t0, 120                       # fase 1 (mista): timer mais lento
    j spawn_timer_guarda
spawn_timer_ogro:
    li t0, OGRE_SPAWN_INTERVALO
spawn_timer_guarda:
    la t1, spawn_timer
    sw t0, 0(t1)
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

# Reaparece gradualmente. Fase 1 (mista, ogro+olho): respeita os tetos por
# tipo. Fase 2 (so ogros): reposicao simples, so ogro.
atualiza_spawn_inimigos:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)
    la t0, nivel_atual
    lw t0, 0(t0)
    li t2, 2
    bge t0, t2, spawn_atualiza_fim
    la t2, spawn_timer
    lw t1, 0(t2)
    addi t1, t1, -1
    bgtz t1, spawn_guarda
    li t2, 1
    beq t0, t2, spawn_fase2_reposicao
    li a0, TIPO_OGRO
    jal conta_tipo
    li t2, MAX_OGROS_FASE2
    blt a0, t2, spawn_ogro_fase1
    li a0, TIPO_OLHO
    jal conta_tipo
    li t2, MAX_OLHOS_FASE2
    bge a0, t2, spawn_guarda
    li s2, TIPO_OLHO
    j spawn_vaga
spawn_fase2_reposicao:
    li t1, OGRE_SPAWN_INTERVALO
    li s2, TIPO_OGRO
    j spawn_vaga
spawn_ogro_fase1:
    li s2, TIPO_OGRO
spawn_vaga:
    la s1, inimigos
    li t2, MAX_INIMIGOS
spawn_vaga_loop:
    beqz t2, spawn_guarda
    lw t3, 8(s1)
    beqz t3, spawn_vaga_achou
    addi s1, s1, TAM_INIMIGO
    addi t2, t2, -1
    j spawn_vaga_loop
spawn_vaga_achou:
    mv a0, s1
    mv a1, s2
    jal spawn_tipo
    la t0, nivel_atual
    lw t0, 0(t0)
    li t2, 1
    beq t0, t2, spawn_rearma_fase2
    li t1, 120
    j spawn_guarda
spawn_rearma_fase2:
    li t1, OGRE_SPAWN_INTERVALO
spawn_guarda:
    la t0, spawn_timer
    sw t1, 0(t0)
spawn_atualiza_fim:
    lw ra, 8(sp)
    lw s1, 4(sp)
    lw s2, 0(sp)
    addi sp, sp, 12
    ret

# a0=slot, a1=tipo. Sorteia posicao afastada do mago e ativa o registro.
spawn_tipo:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    mv s1, a0
    mv s2, a1
    li s3, 10
spawn_tenta:
    li a7, 42
    li a1, 264
    ecall
    addi t0, a0, 16
    li a7, 42
    li a1, 184
    ecall
    addi t1, a0, 16
    la t2, posicao_x_mago
    lw t2, 0(t2)
    la t3, posicao_y_mago
    lw t3, 0(t3)
    sub t4, t0, t2
    bgez t4, spawn_dx_ok
    neg t4, t4
spawn_dx_ok:
    sub t5, t1, t3
    bgez t5, spawn_dy_ok
    neg t5, t5
spawn_dy_ok:
    add t4, t4, t5
    li t5, OGRE_DIST_MIN
    bge t4, t5, spawn_aceita
    addi s3, s3, -1
    bgtz s3, spawn_tenta
spawn_aceita:
    sw t0, 0(s1)
    sw t1, 4(s1)
    li t0, 1
    sw t0, 8(s1)
    sw zero, 12(s1)
    li t0, OGRE_INTERVALO
    li t1, TIPO_OLHO
    bne s2, t1, spawn_timer_ok
    li t0, OLHO_INTERVALO
spawn_timer_ok:
    sw t0, 16(s1)
    sw s2, 20(s1)
    lw ra, 12(sp)
    lw s1, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 16
    ret

# a0=tipo; retorna a0=quantidade ativa.
conta_tipo:
    mv t3, a0
    la t0, inimigos
    li t1, MAX_INIMIGOS
    li a0, 0
conta_tipo_loop:
    beqz t1, conta_tipo_fim
    lw t2, 8(t0)
    beqz t2, conta_tipo_prox
    lw t2, 20(t0)
    bne t2, t3, conta_tipo_prox
    addi a0, a0, 1
conta_tipo_prox:
    addi t0, t0, TAM_INIMIGO
    addi t1, t1, -1
    j conta_tipo_loop
conta_tipo_fim:
    ret

atualiza_inimigos:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)
    la s1, inimigos
    li t6, MAX_INIMIGOS
atualiza_loop:
    beqz t6, atualiza_fim
    lw t0, 8(s1)
    beqz t0, atualiza_prox
    lw t0, 16(s1)
    addi t0, t0, -1
    bgtz t0, atualiza_guarda
    lw t1, 20(s1)
    li t2, TIPO_OLHO
    beq t1, t2, olho_move
    li t0, OGRE_INTERVALO
    li t5, TIPO_OGRO
    j inimigo_calcula
olho_move:
    li t0, OLHO_INTERVALO
    li t5, TIPO_OLHO
inimigo_calcula:
    lw s2, 0(s1)
    lw s3, 4(s1)
    la t3, posicao_x_mago
    lw t3, 0(t3)
    la t4, posicao_y_mago
    lw t4, 0(t4)
    blt s2, t3, inimigo_dir
    bgt s2, t3, inimigo_esq
    j inimigo_x_ok
inimigo_dir:
    addi s2, s2, 2
    li t1, 1
    sw t1, 12(s1)
    j inimigo_x_ok
inimigo_esq:
    addi s2, s2, -2
    sw zero, 12(s1)
inimigo_x_ok:
    blt s3, t4, inimigo_desce
    bgt s3, t4, inimigo_sobe
    j inimigo_y_ok
inimigo_desce:
    addi s3, s3, 2
    j inimigo_y_ok
inimigo_sobe:
    addi s3, s3, -2
inimigo_y_ok:
    # Ogros e olhos podem atravessar a lava.

inimigo_grava:
    sw s2, 0(s1)
    sw s3, 4(s1)
    lw t1, 20(s1)
    li t2, TIPO_OGRO
    bne t1, t2, atualiza_guarda
    jal ogro_checa_lava
    li t0, OGRE_INTERVALO
atualiza_guarda:
    sw t0, 16(s1)
atualiza_prox:
    addi s1, s1, TAM_INIMIGO
    addi t6, t6, -1
    j atualiza_loop
atualiza_fim:
    lw ra, 12(sp)
    lw s1, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 16
    ret

# Impede o ogro de entrar nos quatro pocos de lava da fase 2 (nivel 1).
# a0=x candidato, a1=y candidato; devolve a0=1 quando a posicao e segura.
ogro_pode_andar:
    la t0, nivel_atual
    lw t0, 0(t0)
    li t1, 1
    bne t0, t1, ogro_pos_livre
    li t2, 46
    ble a0, t2, ogro_poco2
    li t2, 102
    bge a0, t2, ogro_poco2
    li t2, 36
    ble a1, t2, ogro_poco2
    li t2, 86
    blt a1, t2, ogro_pos_bloqueada
ogro_poco2:
    li t2, 176
    ble a0, t2, ogro_poco3
    li t2, 232
    bge a0, t2, ogro_poco3
    li t2, 41
    ble a1, t2, ogro_poco3
    li t2, 91
    blt a1, t2, ogro_pos_bloqueada
ogro_poco3:
    li t2, 176
    ble a0, t2, ogro_poco4
    li t2, 232
    bge a0, t2, ogro_poco4
    li t2, 108
    ble a1, t2, ogro_poco4
    li t2, 158
    blt a1, t2, ogro_pos_bloqueada
ogro_poco4:
    li t2, 46
    ble a0, t2, ogro_pos_livre
    li t2, 102
    bge a0, t2, ogro_pos_livre
    li t2, 108
    ble a1, t2, ogro_pos_livre
    li t2, 158
    blt a1, t2, ogro_pos_bloqueada
ogro_pos_livre:
    li a0, 1
    ret
ogro_pos_bloqueada:
    li a0, 0
    ret

ogro_checa_lava:
    addi sp, sp, -4
    sw ra, 0(sp)
    la t0, nivel_atual
    lw t0, 0(t0)
    li t2, 1
    bne t0, t2, ogro_lava_fim
    lw t0, 0(s1)
    lw t1, 4(s1)
    li t2, 46
    ble t0, t2, lava_poco2
    li t2, 102
    bge t0, t2, lava_poco2
    li t2, 36
    ble t1, t2, lava_poco2
    li t2, 86
    blt t1, t2, lava_mata
lava_poco2:
    li t2, 176
    ble t0, t2, lava_poco3
    li t2, 232
    bge t0, t2, lava_poco3
    li t2, 41
    ble t1, t2, lava_poco3
    li t2, 91
    blt t1, t2, lava_mata
lava_poco3:
    li t2, 176
    ble t0, t2, lava_poco4
    li t2, 232
    bge t0, t2, lava_poco4
    li t2, 108
    ble t1, t2, lava_poco4
    li t2, 158
    blt t1, t2, lava_mata
lava_poco4:
    li t2, 46
    ble t0, t2, ogro_lava_fim
    li t2, 102
    bge t0, t2, ogro_lava_fim
    li t2, 108
    ble t1, t2, ogro_lava_fim
    li t2, 158
    bge t1, t2, ogro_lava_fim
lava_mata:
    mv a0, s1
    jal mata_inimigo
ogro_lava_fim:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

draw_inimigos:
    addi sp, sp, -12
    sw ra, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)
    la s1, inimigos
    li s2, MAX_INIMIGOS
draw_inimigos_loop:
    beqz s2, draw_inimigos_fim
    lw t0, 8(s1)
    beqz t0, draw_inimigos_prox
    lw a1, 0(s1)
    lw a2, 4(s1)
    lw t0, 20(s1)
    li t1, TIPO_OLHO
    beq t0, t1, draw_olho
    la a0, vilao
    addi a0, a0, 8
    lw t0, 12(s1)
    li t1, 1024
    mul t0, t0, t1
    add a0, a0, t0
    jal draw_sprite32
    j draw_inimigos_prox
draw_olho:
    la a0, eyeofrah
    addi a0, a0, 8
    jal draw_sprite32
draw_inimigos_prox:
    addi s1, s1, TAM_INIMIGO
    addi s2, s2, -1
    j draw_inimigos_loop
draw_inimigos_fim:
    lw ra, 8(sp)
    lw s1, 4(sp)
    lw s2, 0(sp)
    addi sp, sp, 12
    ret

# a0=pixels (32x32), a1=x, a2=y
draw_sprite32:
    la t0, base_frame_A
    lw t0, 0(t0)
    li t1, 320
    mul t2, a2, t1
    add t0, t0, t2
    add t0, t0, a1
    li t3, 0
draw32_linha:
    li t4, 32
    beq t3, t4, draw32_fim
    mv t5, t0
    li t6, 0
draw32_coluna:
    li t4, 32
    beq t6, t4, draw32_prox_linha
    lb t4, 0(a0)
    beqz t4, draw32_pula
    sb t4, 0(t5)
draw32_pula:
    addi a0, a0, 1
    addi t5, t5, 1
    addi t6, t6, 1
    j draw32_coluna
draw32_prox_linha:
    addi t0, t0, 320
    addi t3, t3, 1
    j draw32_linha
draw32_fim:
    ret

# a0=registro do inimigo. Conta a morte e toca o audio correspondente.
mata_inimigo:
    addi sp, sp, -8
    sw ra, 4(sp)
    sw s1, 0(sp)
    mv s1, a0
    lw t0, 20(s1)
    sw zero, 8(s1)
    li t1, TIPO_OLHO
    beq t0, t1, mata_olho
    jal tocar_som_goblin_morre
    j mata_conta
mata_olho:
    jal tocar_som_olho_morre
mata_conta:
    la t0, inimigos_mortos
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    lw ra, 4(sp)
    lw s1, 0(sp)
    addi sp, sp, 8
    ret