.data
.eqv MAX_INIMIGOS   8
.eqv TAM_INIMIGO    24   # bytes por inimigo (x, y, ativo, direcao, timer, tipo)
.eqv TAM_PX_INIMIGO 32   # largura/altura do inimigo em pixels
.eqv TIPO_OLHO_COLISAO 2

inimigos: .space 192     # MAX_INIMIGOS * TAM_INIMIGO

.text

# Colisão AABB: a0-a3 = x,y,largura,altura do objeto 1
#               a4-a7 = x,y,largura,altura do objeto 2
# retorna a0 = 1 se colidiu, 0 se não
check_collision:
    add t0, a0, a2
    add t2, a1, a3
    add t1, a4, a6
    add t3, a5, a7
    ble t0, a4, no_collision
    bge a0, t1, no_collision
    ble t2, a5, no_collision
    bge a1, t3, no_collision
    li a0, 1
    ret
no_collision:
    li a0, 0
    ret

# Checa colisão do mago com os inimigos ativos (hit-kill: 1 toque já basta)
checar_colisao_mago_inimigos:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s1, 24(sp)
    sw s2, 20(sp)
    sw s3, 16(sp)
    sw s4, 12(sp)
    sw s5, 8(sp)
    sw s6, 4(sp)
    sw s7, 0(sp)

    la t0, posicao_x_mago
    lw s1, 0(t0)
    la t0, posicao_y_mago
    lw s2, 0(t0)
    la t0, tamanho_mago
    lw s3, 0(t0)

    la s4, inimigos
    li s5, MAX_INIMIGOS
    li s6, TAM_INIMIGO
    li s7, TAM_PX_INIMIGO

colisao_loop:
    beqz s5, colisao_fim

    lw t0, 0(s4)
    lw t1, 4(s4)
    lw t2, 8(s4)
    beqz t2, colisao_next

    mv a0, s1
    mv a1, s2
    mv a2, s3
    mv a3, s3
    mv a4, t0
    mv a5, t1
    mv a6, s7
    mv a7, s7

    jal check_collision
    beqz a0, colisao_next

    lw t0, 20(s4)
    li t1, TIPO_OLHO_COLISAO
    beq t0, t1, colisao_olho
    jal mago_atingido
    j colisao_fim
colisao_olho:
    jal mago_atingido_olho
    j colisao_fim

colisao_next:
    add s4, s4, s6
    addi s5, s5, -1
    j colisao_loop

colisao_fim:
    lw ra, 28(sp)
    lw s1, 24(sp)
    lw s2, 20(sp)
    lw s3, 16(sp)
    lw s4, 12(sp)
    lw s5, 8(sp)
    lw s6, 4(sp)
    lw s7, 0(sp)
    addi sp, sp, 32
    ret

map_colision1:
    la t0, nivel_atual
    lw t1, 0(t0)
    li t0, 1
    bne t1, t0, map_colision2

    # Carrega dados do mago
    la t0, posicao_x_mago
    lw a0, 0(t0)
    la t0, posicao_y_mago
    lw a1, 0(t0)
    la t0, tamanho_mago
    lw a2, 0(t0)
    mv a3, a2

    # Carrega dados do poco 1
    li a4, 78
    li a5, 68
    li a6, 24
    li a7, 18

    jal check_collision
    li t0, 1
    beq a0, t0, colidiu

    # Carrega dados do poco 2
    la t0, posicao_x_mago
    lw a0, 0(t0)
    li a4, 208
    li a5, 73
    
    jal check_collision
    li t0, 1
    beq a0, t0, colidiu

    # Carrega dados do poco 3
    la t0, posicao_x_mago
    lw a0, 0(t0)
    li a4, 208
    li a5, 140
    
    jal check_collision
    li t0, 1
    beq a0, t0, colidiu

    # Carrega dados do poco 4
    la t0, posicao_x_mago
    lw a0, 0(t0)
    li a4, 78
    li a5, 140
    
    jal check_collision
    li t0, 1
    beq a0, t0, colidiu

    j map_colision_inimigo1

map_colision2:
    li t0, 2
    bne t1, t0, fim_colision

    # Carrega dados do mago
    la t0, posicao_x_mago
    lw a0, 0(t0)
    la t0, posicao_y_mago
    lw a1, 0(t0)
    la t0, tamanho_mago
    lw a2, 0(t0)
    mv a3, a2

    # Carrega dados do poco 1
    li a4, 1
    li a5, 100
    li a6, 320
    li a7, 20

    jal check_collision
    li t0, 1
    beq a0, t0, colidiu

    j map_colision_inimigo1

colidiu:
    jal mago_atingido

map_colision_inimigo1:
    j fim_after_move             # lava de inimigos agora e tratada no passo do ogro
    la   s3, inimigos
    li   s4, MAX_INIMIGOS
    lw   t2, 8(s3)              # slot ativo?
    beqz t2, fim_colision
    lw   t2, 20(s3)             # olhos voadores ignoram toda lava
    li   t3, 2
    beq  t2, t3, fim_colision
    
    la t0, nivel_atual
    lw t1, 0(t0)
    li t0, 1
    bne t1, t0, map_colision_inimigo2

    # Carrega dados do inimigo
    lw a0, 0(s3)
    lw a1, 4(s3)
    li a2, TAM_PX_INIMIGO
    li a3, TAM_PX_INIMIGO

    # Carrega dados do poco 1
    li a4, 78
    li a5, 68
    li a6, 24
    li a7, 18

    jal check_collision
    li t0, 1
    beq a0, t0, colidiuI

    # Carrega dados do poco 2
    lw a0, 0(s3)
    li a4, 208
    li a5, 73
    
    jal check_collision
    li t0, 1
    beq a0, t0, colidiuI

    # Carrega dados do poco 3
    lw a0, 0(s3)
    li a4, 208
    li a5, 140
    
    jal check_collision
    li t0, 1
    beq a0, t0, colidiuI

    # Carrega dados do poco 4
    lw a0, 0(s3)
    li a4, 78
    li a5, 140
    
    jal check_collision
    li t0, 1
    beq a0, t0, colidiuI

    j fim_colision

map_colision_inimigo2:
    li t0, 2
    bne t1, t0, fim_colision

    # Carrega dados do inimigo
    # Carrega dados do inimigo
    lw a0, 0(s3)
    lw a1, 4(s3)
    li a2, TAM_PX_INIMIGO
    li a3, TAM_PX_INIMIGO

    # Carrega dados do poco 1
    li a4, 1
    li a5, 100
    li a6, 320
    li a7, 20

    jal check_collision
    li t0, 1
    beq a0, t0, colidiuI

    j fim_colision

colidiuI:
    lw t0, 20(s3)              # somente ogros morrem ao tocar lava
    li t1, 2                    # tipo 2 = olho voador
    beq t0, t1, fim_colision
    mv a0, s3
    jal mata_inimigo

fim_colision:
    addi s3, s3, TAM_INIMIGO
    addi s4, s4, -1
    beqz s4, map_colision_inimigo1
    
j fim_after_move