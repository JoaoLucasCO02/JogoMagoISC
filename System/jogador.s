.data
# Sprites dos corações (8x8, 1 byte/pixel RGB332, 0x00 = transparente)
coracao_cheio:
    .word 8, 8, 0
    .byte 0x00,0x07,0x07,0x00,0x00,0x07,0x07,0x00
    .byte 0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07
    .byte 0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07
    .byte 0x07,0x07,0x07,0x07,0x07,0x07,0x07,0x07
    .byte 0x00,0x07,0x07,0x07,0x07,0x07,0x00,0x00
    .byte 0x00,0x00,0x07,0x07,0x07,0x00,0x00,0x00
    .byte 0x00,0x00,0x00,0x07,0x00,0x00,0x00,0x00
    .byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00

coracao_vazio:
    .word 8, 8, 0
    .byte 0x00,0xA4,0xA4,0x00,0x00,0xA4,0xA4,0x00
    .byte 0xA4,0x00,0x00,0x00,0x00,0x00,0x00,0xA4
    .byte 0xA4,0x00,0x00,0x00,0x00,0x00,0x00,0xA4
    .byte 0xA4,0x00,0x00,0x00,0x00,0x00,0x00,0xA4
    .byte 0x00,0xA4,0x00,0x00,0x00,0xA4,0x00,0x00
    .byte 0x00,0x00,0xA4,0x00,0xA4,0x00,0x00,0x00
    .byte 0x00,0x00,0x00,0xA4,0x00,0x00,0x00,0x00
    .byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00

vida_maxima:      .word 3
vida_atual:       .word 3
hud_vida_x:       .word 4
hud_vida_y:       .word 4
hud_vida_espaco:  .word 9

mana_maxima:      .word 100
mana_atual:       .word 65        # valor de exemplo só pra visualização
hud_mana_x:       .word 4
hud_mana_y:       .word 14
hud_mana_largura: .word 26

mago_spawn_x:     .word 148
mago_spawn_y:     .word 180

.text

.eqv MANA_BAR_ALTURA 5
.eqv MANA_COR        0xC0   # azul cheio (formato BBGGGRRR)
.eqv MANA_COR_VAZIA  0x49   # trilho de fundo (azul escuro)

# Função da vida do player: desenha os corações do HUD
draw_hearts:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)

    la t0, vida_maxima
    lw s1, 0(t0)
    la t0, vida_atual
    lw s2, 0(t0)
    li s3, 0

hearts_loop:
    beq s3, s1, hearts_done

    la t0, coracao_cheio
    blt s3, s2, hearts_pick_done
    la t0, coracao_vazio
hearts_pick_done:
    mv a0, t0

    la t1, hud_vida_x
    lw a1, 0(t1)
    la t1, hud_vida_espaco
    lw t2, 0(t1)
    mul t3, s3, t2
    add a1, a1, t3

    la t1, hud_vida_y
    lw a2, 0(t1)

    jal draw_sprite8x8

    addi s3, s3, 1
    j hearts_loop

hearts_done:
    lw ra, 12(sp)
    lw s1, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 16
    ret

# Desenha um sprite 8x8, 1 byte/pixel, 0x00 = transparente
# a0 = sprite (com cabeçalho), a1 = x, a2 = y
draw_sprite8x8:
    la t0, base_frame_A
    lw s0, 0(t0)
    addi a0, a0, 12

    li t1, 320
    mul t2, a2, t1
    add t2, t2, a1
    add t0, s0, t2

    li t3, 0
sprite_row:
    li t4, 8
    beq t3, t4, sprite_row_done
    mv t5, t0
    li t6, 0
sprite_col:
    li t4, 8
    beq t6, t4, sprite_col_done
    lb t4, 0(a0)
    beqz t4, sprite_skip
    sb t4, 0(t5)
sprite_skip:
    addi a0, a0, 1
    addi t5, t5, 1
    addi t6, t6, 1
    j sprite_col
sprite_col_done:
    addi t0, t0, 320
    addi t3, t3, 1
    j sprite_row
sprite_row_done:
    ret

# Função da mana do player: desenha a barra de mana (preenche proporcional)
draw_mana_bar:
    addi sp, sp, -12
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)

    la t0, base_frame_A
    lw s0, 0(t0)

    la t0, mana_atual
    lw s1, 0(t0)
    la t0, mana_maxima
    lw s2, 0(t0)
    la t0, hud_mana_largura
    lw s3, 0(t0)
    mul s1, s1, s3
    div s1, s1, s2          # s1 = largura preenchida (px)

    la t0, hud_mana_x
    lw a1, 0(t0)
    la t0, hud_mana_y
    lw a2, 0(t0)

    li t1, 320
    mul t2, a2, t1
    add t2, t2, a1
    add t0, s0, t2

    li t3, 0
mana_row:
    li t4, MANA_BAR_ALTURA
    beq t3, t4, mana_row_done
    mv t5, t0
    li t6, 0
mana_col:
    beq t6, s3, mana_col_done
    li t4, MANA_COR_VAZIA
    blt t6, s1, mana_col_cheio
    j mana_col_pinta
mana_col_cheio:
    li t4, MANA_COR
mana_col_pinta:
    sb t4, 0(t5)
    addi t5, t5, 1
    addi t6, t6, 1
    j mana_col
mana_col_done:
    addi t0, t0, 320
    addi t3, t3, 1
    j mana_row
mana_row_done:
    lw s1, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 12
    ret

# Adiciona mana (a0 = quantidade), sem passar do máximo
ganha_mana:
    la t0, mana_atual
    lw t1, 0(t0)
    add t1, t1, a0
    la t2, mana_maxima
    lw t3, 0(t2)
    bge t1, t3, mana_no_teto
    sw t1, 0(t0)
    ret
mana_no_teto:
    sw t3, 0(t0)
    ret

# Função de dano do player: aplica hit, mata inimigos da tela e reinicia
mago_atingido:
    addi sp, sp, -4
    sw ra, 0(sp)
    la t0, escudo_timer
    lw t0, 0(t0)
    bgtz t0, mago_sem_dano
    la t0, vida_atual
    lw t1, 0(t0)
    addi t1, t1, -1          # todo contato tira um coracao inteiro
    sw t1, 0(t0)
    blez t1, game_over
    jal tocar_ataque_async
    jal reinicia_rodada
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

mago_atingido_olho:
    addi sp, sp, -4
    sw ra, 0(sp)
    la t0, escudo_timer
    lw t0, 0(t0)
    bgtz t0, mago_olho_sem_dano
    jal tocar_som_olho_ataca_async
    la t0, vida_atual
    lw t1, 0(t0)
    addi t1, t1, -1
    sw t1, 0(t0)
    blez t1, game_over
    jal reinicia_rodada
mago_olho_sem_dano:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

mago_sem_dano:
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

game_over:
    jal tocar_som_mago_morre   # morte: efeito proprio, grave e mais longo
    la t0, game_over_flag       # sinaliza game over; a tela e mostrada no loop
    li t1, 1
    sw t1, 0(t0)
    lw ra, 0(sp)
    addi sp, sp, 4
    ret

reinicia_rodada:
    addi sp, sp, -4
    sw ra, 0(sp)

    la t0, mago_spawn_x
    lw t1, 0(t0)
    la t0, posicao_x_mago
    sw t1, 0(t0)

    la t0, mago_spawn_y
    lw t1, 0(t0)
    la t0, posicao_y_mago
    sw t1, 0(t0)

    la t0, inimigos
    li t1, MAX_INIMIGOS
    li t2, TAM_INIMIGO
matar_loop:
    beqz t1, matar_fim
    sw zero, 8(t0)
    add t0, t0, t2
    addi t1, t1, -1
    j matar_loop
matar_fim:
    jal spawn_inimigos

    lw ra, 0(sp)
    addi sp, sp, 4
    ret