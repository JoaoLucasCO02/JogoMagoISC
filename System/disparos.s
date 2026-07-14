#########################################################################
# Sistema de disparos do mago                                           #
# - Tecla ESPACO cria um disparo na direcao do ultimo movimento (WASD)  #
# - Ate MAX_DISPAROS na tela ao mesmo tempo                             #
# - Ao acertar um inimigo, o inimigo desaparece e o disparo some        #
# - Textura em powershot1.data (orbe 10x10; label "disparo:")               #
#########################################################################

.data
.include "powershot1.data"

.eqv MAX_DISPAROS    8      # maximo de disparos simultaneos na tela
.eqv TAM_DISPARO     20     # bytes por disparo: x, y, ativo, vx, vy
.eqv TAM_PX_DISPARO  10     # largura/altura do disparo em pixels
.eqv DISPARO_VEL     6      # velocidade do disparo (pixels por frame)

# Vetor de disparos. Cada registro (20 bytes):
#   offset 0  -> x (canto superior esquerdo)
#   offset 4  -> y
#   offset 8  -> ativo (0 = livre, 1 = em voo)
#   offset 12 -> vx (deslocamento por frame no eixo x)
#   offset 16 -> vy (deslocamento por frame no eixo y)
disparos: .space 160        # MAX_DISPAROS * TAM_DISPARO

# Direcao de mira = ultimo movimento do mago (componentes -1/0/1).
# Valor inicial (0,-1) = mira para cima antes de qualquer movimento.
dir_x_mago: .word 0
dir_y_mago: .word -1

.text

#########################################################################
# spawn_disparo
# Cria um disparo num slot livre, centralizado no mago, com velocidade
# na direcao de mira atual. Se nao houver slot livre, nao faz nada.
# Rotina folha: usa apenas t0-t6, preservando todos os registradores s.
#########################################################################
spawn_disparo:
    # procura um slot livre (ativo == 0)
    la   t0, disparos
    li   t1, MAX_DISPAROS
    li   t2, TAM_DISPARO
spawn_disp_busca:
    beqz t1, spawn_disp_fim         # sem slot livre: descarta o disparo
    lw   t3, 8(t0)
    beqz t3, spawn_disp_achou
    add  t0, t0, t2
    addi t1, t1, -1
    j    spawn_disp_busca

spawn_disp_achou:
    # posicao inicial: centro do mago (24x24) menos metade do disparo (10/2=5)
    # x = mago_x + 12 - 5 = mago_x + 7 ; y = mago_y + 7
    la   t1, posicao_x_mago
    lw   t1, 0(t1)
    addi t1, t1, 7
    sw   t1, 0(t0)

    la   t2, posicao_y_mago
    lw   t2, 0(t2)
    addi t2, t2, 7
    sw   t2, 4(t0)

    # velocidade = direcao_mira * DISPARO_VEL
    la   t3, dir_x_mago
    lw   t3, 0(t3)
    li   t4, DISPARO_VEL
    mul  t3, t3, t4
    sw   t3, 12(t0)

    la   t5, dir_y_mago
    lw   t5, 0(t5)
    mul  t5, t5, t4
    sw   t5, 16(t0)

    li   t6, 1
    sw   t6, 8(t0)                  # marca como ativo

spawn_disp_fim:
    ret

#########################################################################
# atualiza_disparos
# Move cada disparo ativo, remove os que saem da tela e checa colisao
# com os inimigos ativos (AABB, reusa check_collision). Ao acertar,
# desativa o inimigo e o disparo.
#########################################################################
atualiza_disparos:
    addi sp, sp, -24
    sw   ra, 20(sp)
    sw   s1, 16(sp)
    sw   s2, 12(sp)
    sw   s3, 8(sp)
    sw   s4, 4(sp)
    sw   s5, 0(sp)

    la   s1, disparos
    li   s2, MAX_DISPAROS

atualiza_disp_loop:
    beqz s2, atualiza_disp_fim

    lw   t0, 8(s1)
    beqz t0, atualiza_disp_next     # slot livre, pula

    # move: x += vx ; y += vy
    lw   t0, 0(s1)
    lw   t1, 12(s1)
    add  t0, t0, t1
    sw   t0, 0(s1)

    lw   t2, 4(s1)
    lw   t3, 16(s1)
    add  t2, t2, t3
    sw   t2, 4(s1)

    # saiu da tela? (considerando o tamanho 10x10 -> x em [0,310], y em [0,230])
    bltz t0, atualiza_disp_mata
    li   t4, 310
    bgt  t0, t4, atualiza_disp_mata
    bltz t2, atualiza_disp_mata
    li   t4, 230
    bgt  t2, t4, atualiza_disp_mata

    # checa colisao com cada inimigo ativo
    la   s3, inimigos
    li   s4, MAX_INIMIGOS

atualiza_disp_col:
    beqz s4, atualiza_disp_next
    lw   t5, 8(s3)
    beqz t5, atualiza_disp_col_next # inimigo inativo, pula

    # objeto 1 = disparo (10x10)
    lw   a0, 0(s1)
    lw   a1, 4(s1)
    li   a2, TAM_PX_DISPARO
    li   a3, TAM_PX_DISPARO
    # objeto 2 = inimigo (32x32)
    lw   a4, 0(s3)
    lw   a5, 4(s3)
    li   a6, TAM_PX_INIMIGO
    li   a7, TAM_PX_INIMIGO

    jal  check_collision
    beqz a0, atualiza_disp_col_next

    # acertou: concede mana + tenta dropar powerup, depois some com ambos
    mv   a0, s3                    # ponteiro do inimigo
    jal  ao_matar_inimigo
    sw   zero, 8(s3)                # inimigo inativo
    sw   zero, 8(s1)                # disparo inativo
    j    atualiza_disp_next

atualiza_disp_col_next:
    addi s3, s3, TAM_INIMIGO
    addi s4, s4, -1
    j    atualiza_disp_col

atualiza_disp_mata:
    sw   zero, 8(s1)                # disparo saiu da tela: desativa

atualiza_disp_next:
    addi s1, s1, TAM_DISPARO
    addi s2, s2, -1
    j    atualiza_disp_loop

atualiza_disp_fim:
    lw   ra, 20(sp)
    lw   s1, 16(sp)
    lw   s2, 12(sp)
    lw   s3, 8(sp)
    lw   s4, 4(sp)
    lw   s5, 0(sp)
    addi sp, sp, 24
    ret

#########################################################################
# draw_disparos
# Percorre o vetor e desenha cada disparo ativo.
#########################################################################
draw_disparos:
    addi sp, sp, -12
    sw   ra, 8(sp)
    sw   s1, 4(sp)
    sw   s2, 0(sp)

    la   s1, disparos
    li   s2, MAX_DISPAROS

draw_disparos_loop:
    beqz s2, draw_disparos_fim
    lw   t0, 8(s1)
    beqz t0, draw_disparos_next

    lw   a1, 0(s1)
    lw   a2, 4(s1)
    jal  draw_disparo

draw_disparos_next:
    addi s1, s1, TAM_DISPARO
    addi s2, s2, -1
    j    draw_disparos_loop

draw_disparos_fim:
    lw   ra, 8(sp)
    lw   s1, 4(sp)
    lw   s2, 0(sp)
    addi sp, sp, 12
    ret

#########################################################################
# draw_disparo  (a1 = x, a2 = y)
# Desenha o sprite 10x10 da textura "disparo". 0x00 = transparente.
# Mesmo esquema de draw_vilao: header de 2 words (8 bytes) antes dos pixels.
#########################################################################
draw_disparo:
    la   t0, base_frame_A
    lw   s0, 0(t0)

    la   a0, disparo
    addi a0, a0, 8                  # pula o cabecalho (largura, altura)

    li   t1, 320
    mul  t2, a2, t1
    add  t2, t2, a1
    add  t0, s0, t2                 # endereco do pixel superior esquerdo

    li   t3, 0
draw_disp_row:
    li   t4, TAM_PX_DISPARO
    beq  t3, t4, draw_disp_row_done
    mv   t5, t0
    li   t6, 0
draw_disp_col:
    li   t4, TAM_PX_DISPARO
    beq  t6, t4, draw_disp_col_done
    lb   t4, 0(a0)
    beqz t4, draw_disp_skip         # 0x00 = transparente
    sb   t4, 0(t5)
draw_disp_skip:
    addi a0, a0, 1
    addi t5, t5, 1
    addi t6, t6, 1
    j    draw_disp_col
draw_disp_col_done:
    addi t0, t0, 320
    addi t3, t3, 1
    j    draw_disp_row
draw_disp_row_done:
    ret
