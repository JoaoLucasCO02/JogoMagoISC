.include "MACROSv24.s"

# Ponto de entrada (RARS e FPGRARS): primeira instrucao do .text.
# Evita depender de .globl main, que o FPGRARS nao suporta.
.text
    j main

.data
.include "magomenu.data"
.include "pausemenu.data"
.include "tela.data"
.include "gameover.data"
.include "mago.data"
.include "colisao.s"
.include "jogador.s"
.include "inimigos.s"
.include "disparos.s"
.include "audio.s"
.include "poderes.s"
.data

#Variaveis de memoria salva
base_frame_A:    .word 0xFF000000 #Endereço de memoria do frame atual s0
cd_frame_A:      .word 0 #Codigo do frame atual (0 ou 1) s6
posicao_y_mago:  .word 20 # s1
posicao_x_mago:  .word 24 # s2
tamanho_mago:    .word 24 # s3
tempo_inicio:    .word 0 # s3
tempo_final:     .word 0 # s3
map_adress:      .word 0 # endereco do mapa atual
nivel_atual:     .word 0


.text

# Constantes de vídeo
.eqv VGA_BASE      0xFF000000
.eqv VGA_END       0xFF012C00
.eqv VGA_FRAME_SEL 0xFF200604
.eqv TECLA         0xff200004 # endereço do teclado
.eqv FRAME_TARGET_MS 30

main:
    la t0, map_pixels
    la t1, map_adress
    sw t0, 0(t1)
    li t0, VGA_BASE
    sw zero, 0(t0)
    li s0, VGA_BASE

init_mago:
    la t0, vida_atual
    li t1, 3
    sw t1, 0(t0)
    la t0, mana_atual
    li t1, 65
    sw t1, 0(t0)
    la t0, posicao_x_mago
    li t1, 24
    sw t1, 0(t0)
    la t0, posicao_y_mago
    li t1, 20
    sw t1, 0(t0)

    la t0, inimigos_mortos
    sw zero, 0(t0)

    la t0, inimigos
    li t1, MAX_INIMIGOS
    li t2, TAM_INIMIGO

init_inimigos:
    beqz t1, init_inimigos_fim
    sw zero, 0(t0)
    sw zero, 4(t0)
    sw zero, 8(t0)
    add t0, t0, t2
    addi t1, t1, -1
    j init_inimigos

init_inimigos_fim:

init_disparos:
    la t0, disparos
    li t1, MAX_DISPAROS
    li t2, TAM_DISPARO
init_disparos_loop:
    beqz t1, init_disparos_fim
    sw zero, 8(t0)          # marca o slot como livre
    add t0, t0, t2
    addi t1, t1, -1
    j init_disparos_loop
init_disparos_fim:
    la t0, dir_x_mago       # mira inicial: para cima
    sw zero, 0(t0)
    la t0, dir_y_mago
    li t1, -1
    sw t1, 0(t0)

    jal init_poderes_vetores

    jal draw_menu
    jal tocar_musica_menu  # toca em loop ate ESPACO ser pressionado

    li t0, TECLA           # consome o ESPACO do menu (evita disparo fantasma)
    sw zero, 0(t0)

    jal spawn_inimigos

    jal draw_image
    jal draw_inimigos
    jal draw_square
    jal draw_escudo_aura
    jal draw_disparos
    jal draw_superdisparos
    jal draw_powerups
    jal draw_hearts
    jal draw_mana_bar

#Pausa no inicio da fase
    li a0, 1000
    jal sleep_ms

loop:
    csrr t1, time
    la t0, tempo_inicio
    sw t1, 0(t0)

    jal read_key

    li t0, 'p'
    beq a0, t0, pause_menu
    li t0, 'w'
    beq a0, t0, move_up
    li t0, 'a'
    beq a0, t0, move_left
    li t0, 's'
    beq a0, t0, move_down
    li t0, 'd'
    beq a0, t0, move_right
    li t0, ' '
    beq a0, t0, shoot
    li t0, 'q'
    beq a0, t0, super_shoot
    j after_move

shoot:
    la t0, triplo_timer     # tiro triplo ativo?
    lw t0, 0(t0)
    bgtz t0, shoot_triplo
    jal spawn_disparo
    jal tocar_som_disparo
    j after_move
shoot_triplo:
    jal spawn_tiro_triplo
    jal tocar_som_disparo
    j after_move

super_shoot:
    jal spawn_superdisparo
    beqz a0, after_move     # nao tinha mana cheia: nao disparou, sem som
    jal tocar_som_disparo
    j after_move

pause_menu:
    jal draw_pause

    jal read_key

    li t0, ' '
    beq a0, t0, resume_game
    li t0, 27
    beq a0, t0, exit_program
    li t0, 'r'
    beq a0, t0, init_mago
    li t0, 'n'
    beq a0, t0, next_level
    j pause_menu

next_level:
    la t0, map_adress
    lw t1, 0(t0)
    li t2, 76800
    add t1, t1, t2
    sw t1, 0(t0)
    
    la t0, nivel_atual
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)

    j init_mago

move_up:
    la t0, dir_x_mago      # mira para cima (0,-1)
    sw zero, 0(t0)
    la t0, dir_y_mago
    li t1, -1
    sw t1, 0(t0)
    la t0, posicao_y_mago
    lw s2, 0(t0)
    addi t0, s2, -18 # Limite superior do mapa
    bltz t0, after_move
    addi s2, s2, -4
    j after_move

move_left:
    la t0, dir_x_mago      # mira para a esquerda (-1,0)
    li t1, -1
    sw t1, 0(t0)
    la t0, dir_y_mago
    sw zero, 0(t0)
    la t0, posicao_x_mago
    lw s1, 0(t0)
    addi t0, s1, -18 # Limite esquerdo do mapa
    bltz t0, after_move
    addi s1, s1, -4
    j after_move

move_down:
    la t0, dir_x_mago      # mira para baixo (0,1)
    sw zero, 0(t0)
    la t0, dir_y_mago
    li t1, 1
    sw t1, 0(t0)
    la t0, posicao_y_mago
    lw s2, 0(t0)
    li t0, 192       # Limite inferior do mapa
    bgt s2, t0, after_move
    addi s2, s2, 4
    j after_move

move_right:
    la t0, dir_x_mago      # mira para a direita (1,0)
    li t1, 1
    sw t1, 0(t0)
    la t0, dir_y_mago
    sw zero, 0(t0)
    la t0, posicao_x_mago
    lw s1, 0(t0)
    li t0, 270       # Limite direito do mapa
    bgt s1, t0, after_move
    addi s1, s1, 4
    j after_move

after_move:
    la t0, posicao_x_mago
    sw s1, 0(t0)
    la t0, posicao_y_mago
    sw s2, 0(t0)

    jal checar_colisao_mago_inimigos
    jal atualiza_inimigos
    jal atualiza_spawn_inimigos
    jal atualiza_disparos
    jal atualiza_superdisparos
    jal atualiza_powerups
    
map_colision:
    la t0, nivel_atual
    lw t1, 0(t0)
    li t0, 1
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

    j fim_colision

colidiu:
    jal mago_atingido
    j fim_colision

fim_colision:

    li a0, 0
    li t0, TECLA
    sw a0, 0(t0)

    la t0, game_over_flag   # morreu? mostra a tela de game over
    lw t0, 0(t0)
    bnez t0, tela_game_over

    la t0, cd_frame_A
    lw s6, 0(t0)
    beqz s6, frame0
    j frame1

frame0:
    li s0, VGA_BASE
    la t0, base_frame_A
    sw s0, 0(t0)
    j draw_frame

frame1:
    li s0, 0xFF100000
    la t0, base_frame_A
    sw s0, 0(t0)

draw_frame:
    jal draw_image
    jal draw_inimigos
    jal draw_square
    jal draw_escudo_aura
    jal draw_disparos
    jal draw_superdisparos
    jal draw_powerups
    jal draw_hearts
    jal draw_mana_bar
    li t0, VGA_FRAME_SEL
    sw s6, 0(t0)
    xori s6, s6, 0x1
    la t0, cd_frame_A
    sw s6, 0(t0)
    
    la t0, tempo_inicio
    lw t1, 0(t0)
    csrr t2, time
    li t3, FRAME_TARGET_MS
    sub a0, t2, t1
    sub a0, t3, a0
    bltz a0, no_sleep
    jal sleep_ms
no_sleep:
    j loop

resume_game:
    li t0, TECLA           # consome a tecla usada no pause
    sw zero, 0(t0)
    j loop
    
exit_program:
    li a7, 10
    ecall
    
sleep_ms:
    csrr t0, time
    add t1, t0, a0
sleep_loop:
    csrr t0, time
    bltu t0, t1, sleep_loop
    ret

read_key:
    li t0, TECLA
    lw a0, 0(t0)  # endereço do teclado
    ret

# Copia o mapa da memória pra tela
draw_image:
    la t0, base_frame_A
    lw s0, 0(t0)
    la t1, map_adress
    lw t0, 0(t1)
    mv t1, s0
    li t6, 0x12C00
    add t2, s0, t6
image_loop:
    beq t1, t2, image_done
    lw t3, 0(t0)
    sw t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j image_loop
image_done:
    ret
    
# Copia o menu da memória pra tela
draw_menu:
    la t0, base_frame_A
    lw s0, 0(t0)
    la t0, magomenu
    mv t1, s0
    li t6, 76800
    add t2, s0, t6
menu_loop:
    beq t1, t2, menu_done
    lb t3, 8(t0)
    sb t3, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    j menu_loop
menu_done:
    ret

# Desenha o mago 24x24 na tela
draw_pause:
    la t0, base_frame_A
    lw s0, 0(t0)

    li s1, 50
    li s2, 50

    li s3, 210
    li s4, 120
    mv t0, s0
    li t1, 320
    mul t2, s2, t1
    add t2, t2, s1
    add t0, t0, t2

    la t2, pausemenu
    addi t2, t2, 8
    li t3, 0
    li t6, 320
pause_row:
    beq t3, s4, pause_done
    mv t4, t0
    li t5, 0
pause_col:
    beq t5, s3, pause_next_row
    lb t1, 0(t2)
    sb t1, 0(t4)
    addi t2, t2, 1
    addi t4, t4, 1
    addi t5, t5, 1
    j pause_col
pause_next_row:
    add t0, t0, t6
    addi t3, t3, 1
    j pause_row
pause_done:
    ret

# Desenha o menu de pause na tela
draw_square:
    la t0, base_frame_A
    lw s0, 0(t0)
    la t0, posicao_x_mago
    lw s1, 0(t0)
    la t0, posicao_y_mago
    lw s2, 0(t0)
    la t0, tamanho_mago
    lw s3, 0(t0)
    mv t0, s0
    li t1, 320
    mul t2, s2, t1
    add t2, t2, s1
    add t0, t0, t2

    la t2, mago
    addi t2, t2, 8
    li t3, 0
    li t6, 320
square_row:
    beq t3, s3, square_done
    mv t4, t0
    li t5, 0
square_col:
    beq t5, s3, square_next_row
    lb t1, 0(t2)
    sb t1, 0(t4)
    addi t2, t2, 1
    addi t4, t4, 1
    addi t5, t5, 1
    j square_col
square_next_row:
    add t0, t0, t6
    addi t3, t3, 1
    j square_row
square_done:
    ret

#########################################################################
# Tela de game over: desenha gameover.data no frame 0 e espera tecla.
#   R ou ESPACO -> reinicia (volta ao menu) ; ESC -> sai
#########################################################################
tela_game_over:
    li t0, VGA_FRAME_SEL       # mostra o frame 0
    sw zero, 0(t0)
    li s0, VGA_BASE            # desenha no frame 0
    la t0, base_frame_A
    sw s0, 0(t0)
    jal draw_gameover

    li t0, TECLA               # limpa tecla residual
    sw zero, 0(t0)

go_espera:
    jal read_key
    li t0, 'r'
    beq a0, t0, go_reinicia
    li t0, ' '
    beq a0, t0, go_reinicia
    li t0, 27
    beq a0, t0, exit_program
    j go_espera

go_reinicia:
    li t0, TECLA               # consome a tecla usada
    sw zero, 0(t0)
    j init_mago

# Copia a tela de game over (gameover.data, 320x240) pro frame atual
draw_gameover:
    la t0, base_frame_A
    lw s0, 0(t0)
    la t0, gameover
    mv t1, s0
    li t6, 76800
    add t2, s0, t6
go_draw_loop:
    beq t1, t2, go_draw_done
    lb t3, 8(t0)
    sb t3, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    j go_draw_loop
go_draw_done:
    ret
