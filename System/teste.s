.include "MACROSv24.s"

.data
.include "tela.data"
.include "mago.data"

# Variaveis de memoria salva
base_frame_A:    .word 0xFF000000 # Endereco de memoria do frame atual s0
cd_frame_A:      .word 0          # Codigo do frame atual (0 ou 1) s6
posicao_y_mago:  .word 20         # s1
posicao_x_mago:  .word 24         # s2
tamanho_mago:    .word 24         # s3
tempo_inicio:    .word 0          # t0
tempo_final:     .word 0          # t1

# --- VARIAVEIS DO SISTEMA DE TIRO ---
tiro_ativo:      .word 0          # 0 = inativo, 1 = ativo em tela
tiro_x:          .word 0          # Posicao X do tiro
tiro_y:          .word 0          # Posicao Y do tiro
tiro_dir_x:      .word 0          # Velocidade X do tiro
tiro_dir_y:      .word 0          # Velocidade Y do tiro
mago_u_dir:      .word 4          # Ultima direcao do mago: 1=W(Cima), 2=A(Esq), 3=S(Baixo), 4=D(Dir)

.text

# Constantes de video
.eqv VGA_BASE      0xFF000000
.eqv VGA_END       0xFF012C00
.eqv VGA_FRAME_SEL 0xFF200604
.eqv TECLA         0xff200004     # endereco do teclado
.eqv FRAME_TARGET_MS 40

.globl main       # Diretiva necessaria para o RARS encontrar o inicio do programa
main:
    li t0, VGA_BASE
    sw zero, 0(t0)
    li s0, VGA_BASE

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

    jal spawn_inimigos

    jal draw_image
    jal draw_inimigos
    jal draw_square
    jal draw_hearts
    jal draw_mana_bar

loop:
    li a7, 30
    ecall
    la t0, tempo_inicio
    sw a0, 0(t0)

    jal read_key

    li t0, 27
    beq a0, t0, exit_program
    
    # --- VERIFICA SE APERTOU ESPACO (ASCII 32) ---
    li t0, ' '
    beq a0, t0, atira

    li t0, 'w'
    beq a0, t0, move_up
    li t0, 'a'
    beq a0, t0, move_left
    li t0, 's'
    beq a0, t0, move_down
    li t0, 'd'
    beq a0, t0, move_right
    j after_move

# --- ROTINA PARA DISPARAR O PODER ---
atira:
    la t0, tiro_ativo
    lw t1, 0(t0)
    bnez t1, after_move       # Se ja existe um tiro ativo, ignora o comando (1 tiro por vez)
    
    li t1, 1
    sw t1, 0(t0)              # Ativa o estado do tiro
    
    # Centraliza o tiro 10x10 no meio do Mago 24x24 (offset de +7 pixels)
    la t0, posicao_x_mago
    lw t1, 0(t0)
    addi t1, t1, 7
    la t2, tiro_x
    sw t1, 0(t2)
    
    la t0, posicao_y_mago
    lw t1, 0(t0)
    addi t1, t1, 7
    la t2, tiro_y
    sw t1, 0(t2)
    
    # Define a trajetoria baseado na ultima direcao salva
    la t0, mago_u_dir
    lw t1, 0(t0)
    
    li t2, 1
    beq t1, t2, atira_cima
    li t2, 2
    beq t1, t2, atira_esquerda
    li t2, 3
    beq t1, t2, atira_baixo
    j atira_direita

atira_cima:
    la t0, tiro_dir_x
    sw zero, 0(t0)
    li t1, -6                 # Velocidade do projetil no eixo Y
    la t0, tiro_dir_y
    sw t1, 0(t0)
    j after_move

atira_esquerda:
    li t1, -6                 # Velocidade do projetil no eixo X
    la t0, tiro_dir_x
    sw t1, 0(t0)
    la t0, tiro_dir_y
    sw zero, 0(t0)
    j after_move

atira_baixo:
    la t0, tiro_dir_x
    sw zero, 0(t0)
    li t1, 6
    la t0, tiro_dir_y
    sw t1, 0(t0)
    j after_move

atira_direita:
    li t1, 6
    la t0, tiro_dir_x
    sw t1, 0(t0)
    la t0, tiro_dir_y
    sw zero, 0(t0)
    j after_move

# --- MOVIMENTOS SALVANDO A DIREÇÃO ---
move_up:
    la t0, mago_u_dir
    li t1, 1
    sw t1, 0(t0)              # Salva direcao: Cima
    la t0, posicao_y_mago
    lw s2, 0(t0)
    addi t0, s2, -18 
    bltz t0, after_move
    addi s2, s2, -4
    j after_move

move_left:
    la t0, mago_u_dir
    li t1, 2
    sw t1, 0(t0)              # Salva direcao: Esquerda
    la t0, posicao_x_mago
    lw s1, 0(t0)
    addi t0, s1, -18 
    bltz t0, after_move
    addi s1, s1, -4
    j after_move

move_down:
    la t0, mago_u_dir
    li t1, 3
    sw t1, 0(t0)              # Salva direcao: Baixo
    la t0, posicao_y_mago
    lw s2, 0(t0)
    li t0, 192       
    bgt s2, t0, after_move
    addi s2, s2, 4
    j after_move

move_right:
    la t0, mago_u_dir
    li t1, 4
    sw t1, 0(t0)              # Salva direcao: Direita
    la t0, posicao_x_mago
    lw s1, 0(t0)
    li t0, 270       
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
    
    # --- ATUALIZA POSIÇÃO E COLISÃO DO TIRO ---
    jal atualiza_tiro
    jal checar_colisao_tiro_inimigos
    
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
    jal draw_hearts
    jal draw_mana_bar
    
    # --- DESENHA O TIRO SE ESTIVER ATIVO ---
    jal draw_tiro
    
    li t0, VGA_FRAME_SEL
    sw s6, 0(t0)
    xori s6, s6, 0x1
    la t0, cd_frame_A
    sw s6, 0(t0)

    la t0, tempo_inicio
    lw t1, 0(t0)
    li a7, 30
    ecall
    mv t2, a0
    li t3, FRAME_TARGET_MS
    sub a0, t2, t1
    sub a0, t3, a0
    bltz a0, no_sleep
    li a7, 32
    ecall
no_sleep:
    j loop

exit_program:
    li a7, 10
    ecall

read_key:
    # Leitura correta do MMIO para compatibilidade total
    li t0, TECLA      
    lw a0, 0(t0)      
    andi a0, a0, 0xFF 
    ret

# Copia o mapa da memoria pra tela
draw_image:
    la t0, base_frame_A
    lw s0, 0(t0)
    la t0, map_pixels
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

# Desenha o mago 24x24 na tela
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
    beqz t1, square_skip    # Trata transparencia do mago se o byte for 0
    sb t1, 0(t4)
square_skip:
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

# =========================================================
# SUBROTINAS EXCLUSIVAS DO SISTEMA DE TIRO
# =========================================================

atualiza_tiro:
    la t0, tiro_ativo
    lw t1, 0(t0)
    beqz t1, atualiza_tiro_fim
    
    # Move no eixo X
    la t2, tiro_x
    lw t3, 0(t2)
    la t4, tiro_dir_x
    lw t5, 0(t4)
    add t3, t3, t5
    sw t3, 0(t2)
    
    # Move no eixo Y
    la t2, tiro_y
    lw t3, 0(t2)
    la t4, tiro_dir_y
    lw t5, 0(t4)
    add t3, t3, t5
    sw t3, 0(t2)
    
    # Apaga se sair das bordas da tela (X < 0 ou X > 310, Y < 0 ou Y > 230)
    la t2, tiro_x
    lw t3, 0(t2)
    bltz t3, apaga_tiro
    li t4, 310
    bgt t3, t4, apaga_tiro
    
    la t2, tiro_y
    lw t3, 0(t2)
    bltz t3, apaga_tiro
    li t4, 230
    bgt t3, t4, apaga_tiro
    ret
    
apaga_tiro:
    la t0, tiro_ativo
    sw zero, 0(t0)
atualiza_tiro_fim:
    ret

checar_colisao_tiro_inimigos:
    la t0, tiro_ativo
    lw t1, 0(t0)
    beqz t1, colisao_tiro_fim
    
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s1, 24(sp)
    sw s2, 20(sp)
    sw s3, 16(sp)
    sw s4, 12(sp)
    sw s5, 8(sp)
    sw s6, 4(sp)
    sw s7, 0(sp)
    
    la t0, tiro_x
    lw s1, 0(t0)
    la t0, tiro_y
    lw s2, 0(t0)
    li s3, 10              # Tamanho do Projetil (10 px)
    
    la s4, inimigos
    li s5, MAX_INIMIGOS
    li s6, TAM_INIMIGO
    li s7, TAM_PX_INIMIGO  # Tamanho do Ogro (32 px)
    
colisao_tiro_loop:
    beqz s5, colisao_tiro_done
    
    lw t0, 0(s4)           # Inimigo X
    lw t1, 4(s4)           # Inimigo Y
    lw t2, 8(s4)           # Inimigo Ativo?
    beqz t2, colisao_tiro_next
    
    # Parametros do Objeto 1 (Tiro)
    mv a0, s1              
    mv a1, s2              
    mv a2, s3              
    mv a3, s3              
    # Parametros do Objeto 2 (Ogro/Vilao)
    mv a4, t0              
    mv a5, t1              
    mv a6, s7              
    mv a7, s7              
    
    jal check_collision
    beqz a0, colisao_tiro_next
    
    # SE COLIDIR: Apaga o Ogro chamando a rotina do inimigos.s
    mv a0, s4              
    jal mata_inimigo
    
    # Desativa o tiro imediatamente
    la t0, tiro_ativo
    sw zero, 0(t0)
    j colisao_tiro_done
    
colisao_tiro_next:
    add s4, s4, s6
    addi s5, s5, -1
    j colisao_tiro_loop
    
colisao_tiro_done:
    lw ra, 28(sp)
    lw s1, 24(sp)
    lw s2, 20(sp)
    lw s3, 16(sp)
    lw s4, 12(sp)
    lw s5, 8(sp)
    lw s6, 4(sp)
    lw s7, 0(sp)
    addi sp, sp, 32
colisao_tiro_fim:
    ret

draw_tiro:
    la t0, tiro_ativo
    lw t1, 0(t0)
    beqz t1, draw_tiro_fim
    
    la t0, base_frame_A
    lw s0, 0(t0)
    la t0, tiro_x
    lw s1, 0(t0)
    la t0, tiro_y
    lw s2, 0(t0)
    
    # Calcula coordenada de video: s0 + (y * 320) + x
    li t1, 320
    mul t2, s2, t1
    add t2, t2, s1
    add t0, s0, t2         # t0 = endereco inicial do projetil em memoria
    
    li t1, 0               # Contador de linhas do quadrado
    li t3, 10              # Altura/Largura limite (10px)
    li t4, 0xFF            # Cor Branca (Formato BBGGGRRR)
    li t6, 320
    
tiro_row_loop:
    beq t1, t3, draw_tiro_fim
    mv t5, t0              # Ponteiro para desenhar colunas
    li t2, 0               # Contador de colunas
    
tiro_col_loop:
    beq t2, t3, tiro_next_row
    sb t4, 0(t5)           # Escreve o pixel na memoria de video
    addi t5, t5, 1
    addi t2, t2, 1
    j tiro_col_loop
    
tiro_next_row:
    add t0, t0, t6         # Salta 320 bytes para ir para a linha de baixo
    addi t1, t1, 1
    j tiro_row_loop
    
draw_tiro_fim:
    ret

# =========================================================
# COMPILAÇÃO DOS ARQUIVOS INCLUÍDOS (Segurança de Memória)
# =========================================================
.include "colisao.s"
.include "jogador.s"
.include "inimigos.s"