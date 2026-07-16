.include "MACROSv24.s"

# Ponto de entrada (RARS e FPGRARS): primeira instrucao do .text.
# Evita depender de .globl main, que o FPGRARS nao suporta.
.text
    j main

.data
.include "magomenu.data"
.include "pausemenu.data"
.include "tela.data"
.include "vitoria.data"
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
base_frame_A:    .word 0xFF000000 #Endereco de memoria do frame atual s0
cd_frame_A:      .word 0 #Codigo do frame atual (0 ou 1) s6
posicao_y_mago:  .word 20 # s1
posicao_x_mago:  .word 24 # s2
tamanho_mago:    .word 24 # s3
tempo_inicio:    .word 0 # s3
tempo_final:     .word 0 # s3
map_adress:      .word 0 # endereco do mapa atual
nivel_atual:     .word 0
mago_disparou:   .word 0
pular_menu:      .word 0  # 1 = ao entrar em init_mago, nao mostra o menu (usado por next_level)

# a =0, s = 1, ap =2, d = 3, dp = 4,

.text

# Constantes de video
.eqv VGA_BASE      0xFF000000
.eqv VGA_END       0xFF012C00
.eqv VGA_FRAME_SEL 0xFF200604
.eqv TECLA         0xff200004 # endereco do teclado
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
    la t0, mago_spawn_x 
    lw t1, 0(t0)
    la t0,  posicao_x_mago
    sw t1, 0(t0)
    la t0, mago_spawn_y
    lw t1, 0(t0)
    la t0,  posicao_y_mago
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

    la t0, pular_menu
    lw t1, 0(t0)
    bnez t1, pula_intro_menu   # veio de next_level: nao mostra o menu de novo

    jal draw_menu
    jal tocar_musica_menu  # toca em loop ate ESPACO ser pressionado

    li t0, TECLA           # consome o ESPACO do menu (evita disparo fantasma)
    sw zero, 0(t0)
    j intro_menu_fim

pula_intro_menu:
    la t0, pular_menu
    sw zero, 0(t0)         # consome a flag
intro_menu_fim:

    jal spawn_inimigos
    jal init_chefe

    jal draw_image
    jal draw_inimigos
    jal draw_square
    jal draw_escudo_aura
    jal draw_chefe
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
    
    la t0, mago_disparou
    lw t1, 0(t0)
    addi t1, t1, -1
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
    li t1, 10
    la t0, mago_disparou   
    sw t1, 0(t0)
    la t0, triplo_timer     # tiro triplo ativo?
    lw t0, 0(t0)
    bgtz t0, shoot_triplo
    jal spawn_disparo
    jal tocar_som_disparo
    j after_move
shoot_triplo:
    li t1, 10
    la t0, mago_disparou   
    sw t1, 0(t0)
    jal spawn_tiro_triplo
    jal tocar_som_disparo
    j after_move

super_shoot:
    li t1, 30
    la t0, mago_disparou   
    sw t1, 0(t0)
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
    la t0, inimigos_mortos
    sw zero, 0(t0)

    jal draw_image
    jal frameM3

    li a0, 3000
    jal sleep_ms

    la t0, map_adress
    lw t1, 0(t0)
    li t2, 76800
    add t1, t1, t2
    sw t1, 0(t0)
    
    la t0, nivel_atual
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)

    li t0, 3
    beq t0, t1, venceu

    la t0, pular_menu       # avanco de fase: nao mostra o menu inicial de novo
    li t1, 1
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
    # fase 3 (nivel 2): mago preso a parte de baixo, abaixo do rio de lava
    la t0, nivel_atual
    lw t0, 0(t0)
    li t1, 2
    bne t0, t1, am_sem_trava
    li t1, 140
    bge s2, t1, am_sem_trava
    li s2, 140
am_sem_trava:
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
    jal map_colision1
fim_after_move:
    jal atualiza_chefe

    # fase 3 (nivel 2): vitoria quando o chefe morre
    la t0, nivel_atual
    lw t0, 0(t0)
    li t1, 2
    bne t0, t1, checa_meta_comum
    la t0, boss_hp
    lw t0, 0(t0)
    blez t0, vitoria_chefe
    j checa_meta_fim
checa_meta_comum:
    # atingiu a meta de abates: zera o contador e passa de fase
    la t0, inimigos_mortos
    lw t1, 0(t0)
    li t3, META_INIMIGOS_FASE
    bge t1, t3, next_level
checa_meta_fim:

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
    jal draw_chefe
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
    la t2, mago

    la t0, dir_y_mago
    lw t0, 0(t0)
    li t1, -1
    beq t0, t1, frameM2
    li t1, 1
    beq t0, t1, frameM1
    
    la t0, mago_disparou
    lw t0, 0(t0)
    bge t0, zero, draw_m_d

    la t0, dir_x_mago
    lw t0, 0(t0)
    li t1, -1
    beq t0, t1, frameM0
    li t1, 1
    beq t0, t1, frameM6

draw_m_d:
    la t0, dir_x_mago
    lw t0, 0(t0)
    li t1, -1
    beq t0, t1, frameM5
    li t1, 1
    beq t0, t1, frameM4
    addi t2, t2, 8

draw_square1:

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
    mul t3, s2, t1
    add t3, t3, s1
    add t0, t0, t3

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


frameM0:
    addi t2, t2, 8
    j draw_square1
frameM1:
    li t0, 584     # 24*24 + 8 = 584
    add t2, t2, t0
    j draw_square1
frameM2:
    li t0, 1160     # 24*24*2 + 8 = 584
    add t2, t2, t0
    j draw_square1
frameM3:
    la t2, mago
    li t0, 1736     # 24*24*3 + 8 = 584
    add t2, t2, t0
    j draw_square1
frameM4:
    li t0, 2312     # 24*24*4 + 8 = 584
    add t2, t2, t0
    j draw_square1
frameM5:
    li t0, 2888     # 24*24*5 + 8 = 584
    add t2, t2, t0
    j draw_square1
frameM6:
    li t0, 3464     # 24*24*6 + 8 = 584
    add t2, t2, t0
    j draw_square1

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

    la t0, nivel_atual
    sw zero, 0(t0)

    la t0, map_pixels
    la t1, map_adress
    sw t0, 0(t1)

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

venceu:
    la t0, base_frame_A
    lw s0, 0(t0)
    la t0, vitoria
    mv t1, s0
    li t6, 76800
    add t2, s0, t6
venceu_loop:
    beq t1, t2, venceu_done
    lb t3, 8(t0)
    sb t3, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    j venceu_loop
venceu_done:
jal tocar_musica_menu
j exit_program

#########################################################################
# vitoria_chefe - fim da fase 3: animacao do mago (positivo, como no fim
# das fases 1 e 2), depois a tela vitoria.data; ESPACO volta ao menu.
#########################################################################
vitoria_chefe:
    li t0, VGA_FRAME_SEL       # mostra o frame 0
    sw zero, 0(t0)
    li t1, VGA_BASE            # desenha no frame 0
    la t0, base_frame_A
    sw t1, 0(t0)
    jal draw_image             # mapa da fase 3
    jal frameM3                # mago fazendo o positivo
    li a0, 3000
    jal sleep_ms
    jal desenha_vitoria        # tela de vitoria
    li t0, TECLA
    sw zero, 0(t0)
vch_espera:
    jal read_key
    li t0, ' '                 # ESPACO volta ao menu
    beq a0, t0, vch_menu
    j vch_espera
vch_menu:
    la t0, nivel_atual         # reinicia do zero e volta ao menu
    sw zero, 0(t0)
    la t0, pular_menu
    sw zero, 0(t0)
    li t0, TECLA
    sw zero, 0(t0)
    j main

# desenha_vitoria - copia vitoria.data para o frame atual
desenha_vitoria:
    la t0, base_frame_A
    lw s0, 0(t0)
    la t0, vitoria
    mv t1, s0
    li t6, 76800
    add t2, s0, t6
dvit_loop:
    beq t1, t2, dvit_done
    lb t3, 8(t0)
    sb t3, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    j dvit_loop
dvit_done:
    ret

.include "chefe.s"
