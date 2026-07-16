#########################################################################
# Poderes do mago: SUPERGOLPE + POWERUPS                                #
#                                                                       #
# SUPERGOLPE (tecla 'q'):                                               #
#   - So dispara quando a barra de mana esta cheia; consome toda a mana #
#   - Projetil 50x50 que viaja na direcao de mira (igual ao tiro normal)#
#   - Atravessa e mata todos os inimigos que tocar ate sair da tela     #
#   - Textura em superdisparo.data (label "superdisparo:")              #
#                                                                       #
# POWERUPS (dropam ao matar um inimigo a tiro):                         #
#   - Coracao : recupera 1 vida (ate o maximo)      -> instantaneo      #
#   - Triplo  : espaco passa a atirar 3 tiros em leque -> temporario    #
#   - Escudo  : mago fica invencivel                -> temporario       #
#   Item fica no chao por um tempo; se nao pego, some.                  #
#                                                                       #
# Mana: o mago ganha MANA_POR_KILL a cada inimigo morto a tiro.         #
#########################################################################

.data

# ---- Supergolpe ----
# Registro (20 bytes): x(0), y(4), ativo(8), vx(12), vy(16)
superdisparos: .space 60        # MAX_SUPER * TAM_SUPER

# ---- Powerups no chao ----
# Registro (20 bytes): x(0), y(4), ativo(8), tipo(12), timer(16)
powerups:      .space 120       # MAX_POWERUPS * TAM_POWERUP

# ---- Buffs temporarios (frames restantes) ----
escudo_timer:  .word 0
triplo_timer:  .word 0
game_over_flag: .word 0         # 1 quando as vidas do mago acabam

.include "superdisparo.data"
.include "powerups.data"

.eqv MAX_SUPER      3
.eqv TAM_SUPER      20
.eqv TAM_PX_SUPER   50
.eqv SUPER_VEL      6

.eqv MAX_POWERUPS   6
.eqv TAM_POWERUP    20
.eqv TAM_PX_POWERUP 20
.eqv POWERUP_VIDA   300         # ~9s de vida do item no chao
.eqv DROP_CHANCE    3           # 1 em 3 (~33%) dropa
.eqv NUM_TIPOS      3
.eqv BUFF_DURACAO   233         # ~7s de duracao do tiro triplo (30ms/frame)
.eqv ESCUDO_DURACAO 200         # ~6s de imunidade (valor original)

.eqv MANA_POR_KILL  20          # mana ganha por inimigo morto

.eqv PU_CORACAO     0
.eqv PU_TRIPLO      1
.eqv PU_ESCUDO      2

.text

#########################################################################
# init_poderes_vetores — zera supergolpes, powerups e timers de buff.
# Chamar dentro do init_mago. Rotina folha.
#########################################################################
init_poderes_vetores:
    la   t0, superdisparos
    li   t1, MAX_SUPER
    li   t2, TAM_SUPER
ipv_super:
    beqz t1, ipv_super_fim
    sw   zero, 8(t0)
    add  t0, t0, t2
    addi t1, t1, -1
    j    ipv_super
ipv_super_fim:
    la   t0, powerups
    li   t1, MAX_POWERUPS
    li   t2, TAM_POWERUP
ipv_pu:
    beqz t1, ipv_pu_fim
    sw   zero, 8(t0)
    add  t0, t0, t2
    addi t1, t1, -1
    j    ipv_pu
ipv_pu_fim:
    la   t0, escudo_timer
    sw   zero, 0(t0)
    la   t0, triplo_timer
    sw   zero, 0(t0)
    la   t0, game_over_flag
    sw   zero, 0(t0)
    ret

# Concede mana e rola a chance de dropar um powerup na posicao do inimigo.
# Preserva s1/s2 (usados pela rotina) para nao atrapalhar quem chamou.
#########################################################################
ao_matar_inimigo:
    addi sp, sp, -12
    sw   ra, 8(sp)
    sw   s1, 4(sp)
    sw   s2, 0(sp)

    lw   s1, 0(a0)                 # x do inimigo
    lw   s2, 4(a0)                 # y do inimigo

    li   a0, MANA_POR_KILL         # ganha mana
    jal  ganha_mana

    li   a7, 42                    # rola drop: rand em [0, DROP_CHANCE)
    li   a1, DROP_CHANCE
    ecall
    bnez a0, ami_fim               # so dropa quando cair em 0

    li   a7, 42                    # sorteia o tipo do powerup
    li   a1, NUM_TIPOS
    ecall                          # a0 = tipo em [0, NUM_TIPOS)

    mv   a1, s1                    # x do inimigo
    mv   a2, s2                    # y do inimigo
    jal  spawn_powerup

ami_fim:
    lw   ra, 8(sp)
    lw   s1, 4(sp)
    lw   s2, 0(sp)
    addi sp, sp, 12
    ret

#########################################################################
# ganha_vida — soma 1 vida ao mago, sem passar do maximo. Rotina folha.
#########################################################################
ganha_vida:
    la   t0, vida_atual
    lw   t1, 0(t0)
    la   t2, vida_maxima
    lw   t2, 0(t2)
    bge  t1, t2, ganha_vida_fim
    addi t1, t1, 1
    sw   t1, 0(t0)
ganha_vida_fim:
    ret

#########################################################################
# tocar_morte_async — som de inimigo morrendo, ASSINCRONO (a7=31), pra
# nao congelar o jogo. A versao sincrona do audio.s (tocar_som_goblin_
# morre) trava ~0.6s por morte, o que fica ruim com o supergolpe.
#########################################################################
tocar_morte_async:
    li   a0, 79
    li   a1, 130
    li   a2, 30                    # Overdriven Guitar (mesmo do audio.s)
    li   a3, 100
    li   a7, 31
    ecall
    li   a0, 69
    li   a1, 140
    li   a2, 30
    li   a3, 100
    li   a7, 31
    ecall
    ret

#########################################################################
# tocar_ataque_async — som do ogro acertando o mago, ASSINCRONO (a7=31).
# Mesmas notas do tocar_som_goblin_ataca do audio.s, mas sem travar o
# jogo e usando o mesmo ecall (31) da musica do menu, garantido no FPGRARS.
#########################################################################
tocar_ataque_async:
    li   a0, 50
    li   a1, 150
    li   a2, 30
    li   a3, 110
    li   a7, 31
    ecall
    li   a0, 54
    li   a1, 180
    li   a2, 30
    li   a3, 110
    li   a7, 31
    ecall
    ret

#########################################################################
# spawn_powerup (a0 = tipo, a1 = x do inimigo, a2 = y do inimigo)
# Cria um item num slot livre, centralizado sobre o inimigo. Rotina folha.
#########################################################################
spawn_powerup:
    la   t0, powerups
    li   t1, MAX_POWERUPS
    li   t2, TAM_POWERUP
sp_busca:
    beqz t1, sp_fim                # sem slot livre: ignora
    lw   t3, 8(t0)
    beqz t3, sp_achou
    add  t0, t0, t2
    addi t1, t1, -1
    j    sp_busca
sp_achou:
    addi t3, a1, 6                 # centraliza item 20x20 no inimigo 32x32
    sw   t3, 0(t0)
    addi t3, a2, 6
    sw   t3, 4(t0)
    li   t3, 1
    sw   t3, 8(t0)                 # ativo
    sw   a0, 12(t0)                # tipo
    li   t3, POWERUP_VIDA
    sw   t3, 16(t0)                # vida do item
sp_fim:
    ret

#########################################################################
# spawn_disparo_vel (a0 = vx, a1 = vy)
# Cria um disparo NORMAL (10x10) no vetor "disparos" com a velocidade dada.
# Usado pelo tiro triplo. Rotina folha.
#########################################################################
spawn_disparo_vel:
    la   t0, disparos
    li   t1, MAX_DISPAROS
    li   t2, TAM_DISPARO
sdv_busca:
    beqz t1, sdv_fim
    lw   t3, 8(t0)
    beqz t3, sdv_achou
    add  t0, t0, t2
    addi t1, t1, -1
    j    sdv_busca
sdv_achou:
    la   t3, posicao_x_mago
    lw   t3, 0(t3)
    addi t3, t3, 7
    sw   t3, 0(t0)
    la   t3, posicao_y_mago
    lw   t3, 0(t3)
    addi t3, t3, 7
    sw   t3, 4(t0)
    sw   a0, 12(t0)
    sw   a1, 16(t0)
    li   t3, 1
    sw   t3, 8(t0)
sdv_fim:
    ret

#########################################################################
# spawn_tiro_triplo
# Dispara 3 tiros normais em leque na direcao de mira:
#   central = dir*VEL ; laterais = central +/- perpendicular
# perpendicular de (dx,dy) = (dy,-dx), escalado pra abrir o leque.
#########################################################################
spawn_tiro_triplo:
    addi sp, sp, -20
    sw   ra, 16(sp)
    sw   s1, 12(sp)
    sw   s2, 8(sp)
    sw   s3, 4(sp)
    sw   s4, 0(sp)

    la   t0, dir_x_mago
    lw   t0, 0(t0)                 # dx
    la   t1, dir_y_mago
    lw   t1, 0(t1)                 # dy
    li   t2, DISPARO_VEL
    mul  s1, t0, t2                # vx central
    mul  s2, t1, t2                # vy central

    li   t2, 3                     # abertura do leque
    mul  s3, t1, t2                # perpx =  dy*3
    neg  t3, t0
    mul  s4, t3, t2                # perpy = -dx*3

    mv   a0, s1                    # tiro central
    mv   a1, s2
    jal  spawn_disparo_vel

    add  a0, s1, s3                # tiro lateral 1
    add  a1, s2, s4
    jal  spawn_disparo_vel

    sub  a0, s1, s3                # tiro lateral 2
    sub  a1, s2, s4
    jal  spawn_disparo_vel

    lw   ra, 16(sp)
    lw   s1, 12(sp)
    lw   s2, 8(sp)
    lw   s3, 4(sp)
    lw   s4, 0(sp)
    addi sp, sp, 20
    ret

#########################################################################
# spawn_superdisparo
# Se a mana estiver cheia, zera a mana e cria um supergolpe 50x50 na
# direcao de mira, centralizado no mago. Rotina folha.
#########################################################################
spawn_superdisparo:
    la   t0, mana_atual
    lw   t0, 0(t0)
    la   t1, mana_maxima
    lw   t1, 0(t1)
    blt  t0, t1, ssd_fim          # mana insuficiente: nao faz nada

    la   t0, mana_atual           # consome toda a mana
    sw   zero, 0(t0)

    la   t0, superdisparos
    li   t1, MAX_SUPER
    li   t2, TAM_SUPER
ssd_busca:
    beqz t1, ssd_fim
    lw   t3, 8(t0)
    beqz t3, ssd_achou
    add  t0, t0, t2
    addi t1, t1, -1
    j    ssd_busca
ssd_achou:
    la   t1, posicao_x_mago       # centraliza 50x50 no mago 24x24: -13
    lw   t1, 0(t1)
    addi t1, t1, -13
    sw   t1, 0(t0)
    la   t2, posicao_y_mago
    lw   t2, 0(t2)
    addi t2, t2, -13
    sw   t2, 4(t0)

    li   t4, SUPER_VEL
    la   t3, dir_x_mago
    lw   t3, 0(t3)
    mul  t3, t3, t4
    sw   t3, 12(t0)               # vx
    la   t5, dir_y_mago
    lw   t5, 0(t5)
    mul  t5, t5, t4
    sw   t5, 16(t0)               # vy

    li   t6, 1
    sw   t6, 8(t0)                # ativo
    li   a0, 1                    # disparou
    ret
ssd_fim:
    li   a0, 0                    # nao disparou (mana insuficiente ou sem slot)
    ret

#########################################################################
# atualiza_superdisparos
# Move cada supergolpe ativo; some ao sair da tela (caixa 50x50 -> x em
# [0,270], y em [0,190]); ao tocar um inimigo, mata o inimigo (com mana +
# drop) mas o supergolpe CONTINUA (atravessa).
#########################################################################
atualiza_superdisparos:
    addi sp, sp, -24
    sw   ra, 20(sp)
    sw   s1, 16(sp)
    sw   s2, 12(sp)
    sw   s3, 8(sp)
    sw   s4, 4(sp)
    sw   s5, 0(sp)

    la   s1, superdisparos
    li   s2, MAX_SUPER
asd_loop:
    beqz s2, asd_fim
    lw   t0, 8(s1)
    beqz t0, asd_next

    lw   t0, 0(s1)                 # move x
    lw   t1, 12(s1)
    add  t0, t0, t1
    sw   t0, 0(s1)
    lw   t2, 4(s1)                 # move y
    lw   t3, 16(s1)
    add  t2, t2, t3
    sw   t2, 4(s1)

    bltz t0, asd_mata              # saiu da tela?
    li   t4, 270
    bgt  t0, t4, asd_mata
    bltz t2, asd_mata
    li   t4, 190
    bgt  t2, t4, asd_mata

    la   s3, inimigos             # checa contra cada inimigo ativo
    li   s4, MAX_INIMIGOS
asd_col:
    beqz s4, asd_next
    lw   t5, 8(s3)
    beqz t5, asd_col_next

    lw   a0, 0(s1)                 # supergolpe (50x50)
    lw   a1, 4(s1)
    li   a2, TAM_PX_SUPER
    li   a3, TAM_PX_SUPER
    lw   a4, 0(s3)                 # inimigo (32x32)
    lw   a5, 4(s3)
    li   a6, TAM_PX_INIMIGO
    li   a7, TAM_PX_INIMIGO
    jal  check_collision
    beqz a0, asd_col_next

    mv   a0, s3                    # mata inimigo (mana + drop); super atravessa
    jal  ao_matar_inimigo
    mv   a0, s3                    # conta o abate, toca o som e marca inativo
    jal  mata_inimigo

asd_col_next:
    addi s3, s3, TAM_INIMIGO
    addi s4, s4, -1
    j    asd_col

asd_mata:
    sw   zero, 8(s1)

asd_next:
    addi s1, s1, TAM_SUPER
    addi s2, s2, -1
    j    asd_loop

asd_fim:
    lw   ra, 20(sp)
    lw   s1, 16(sp)
    lw   s2, 12(sp)
    lw   s3, 8(sp)
    lw   s4, 4(sp)
    lw   s5, 0(sp)
    addi sp, sp, 24
    ret

#########################################################################
# atualiza_powerups
# 1) Decrementa os timers dos buffs (escudo, triplo).
# 2) Para cada item ativo: decrementa a vida do item (some se zerar) e
#    checa colisao com o mago; ao pegar, aplica o efeito.
#########################################################################
atualiza_powerups:
    addi sp, sp, -12
    sw   ra, 8(sp)
    sw   s1, 4(sp)
    sw   s2, 0(sp)

    la   t0, escudo_timer         # conta o escudo
    lw   t1, 0(t0)
    blez t1, ap_esc0
    addi t1, t1, -1
    sw   t1, 0(t0)
ap_esc0:
    la   t0, triplo_timer         # conta o triplo
    lw   t1, 0(t0)
    blez t1, ap_tri0
    addi t1, t1, -1
    sw   t1, 0(t0)
ap_tri0:
    la   s1, powerups
    li   s2, MAX_POWERUPS
ap_loop:
    beqz s2, ap_fim
    lw   t0, 8(s1)
    beqz t0, ap_next

    lw   t0, 16(s1)               # vida do item
    addi t0, t0, -1
    sw   t0, 16(s1)
    blez t0, ap_expira

    lw   a0, 0(s1)                # colisao item(14x14) x mago(24x24)
    lw   a1, 4(s1)
    li   a2, TAM_PX_POWERUP
    li   a3, TAM_PX_POWERUP
    la   t0, posicao_x_mago
    lw   a4, 0(t0)
    la   t0, posicao_y_mago
    lw   a5, 0(t0)
    la   t0, tamanho_mago
    lw   a6, 0(t0)
    mv   a7, a6
    jal  check_collision
    beqz a0, ap_next

    lw   t0, 12(s1)               # pegou: aplica pelo tipo
    li   t1, PU_CORACAO
    beq  t0, t1, ap_coracao
    li   t1, PU_TRIPLO
    beq  t0, t1, ap_triplo

    li   t1, ESCUDO_DURACAO      # senao: escudo (imunidade, tempo original)
    la   t0, escudo_timer
    sw   t1, 0(t0)
    j    ap_pega_fim
ap_coracao:
    jal  ganha_vida
    j    ap_pega_fim
ap_triplo:
    li   t1, BUFF_DURACAO
    la   t0, triplo_timer
    sw   t1, 0(t0)
ap_pega_fim:
    sw   zero, 8(s1)              # consome o item
    j    ap_next
ap_expira:
    sw   zero, 8(s1)              # item some (tempo esgotado)
ap_next:
    addi s1, s1, TAM_POWERUP
    addi s2, s2, -1
    j    ap_loop
ap_fim:
    lw   ra, 8(sp)
    lw   s1, 4(sp)
    lw   s2, 0(sp)
    addi sp, sp, 12
    ret

#########################################################################
# draw_superdisparos / draw_superdisparo (50x50, 0x00 = transparente)
#########################################################################
draw_superdisparos:
    addi sp, sp, -12
    sw   ra, 8(sp)
    sw   s1, 4(sp)
    sw   s2, 0(sp)
    la   s1, superdisparos
    li   s2, MAX_SUPER
dss_loop:
    beqz s2, dss_fim
    lw   t0, 8(s1)
    beqz t0, dss_next
    lw   a1, 0(s1)
    lw   a2, 4(s1)
    jal  draw_superdisparo
dss_next:
    addi s1, s1, TAM_SUPER
    addi s2, s2, -1
    j    dss_loop
dss_fim:
    lw   ra, 8(sp)
    lw   s1, 4(sp)
    lw   s2, 0(sp)
    addi sp, sp, 12
    ret

# a1 = x, a2 = y
draw_superdisparo:
    la   t0, base_frame_A
    lw   s0, 0(t0)
    la   a0, superdisparo
    addi a0, a0, 8                 # pula header (2 words)
    li   t1, 320
    mul  t2, a2, t1
    add  t2, t2, a1
    add  t0, s0, t2
    li   t3, 0
dsd_row:
    li   t4, TAM_PX_SUPER
    beq  t3, t4, dsd_row_done
    mv   t5, t0
    li   t6, 0
dsd_col:
    li   t4, TAM_PX_SUPER
    beq  t6, t4, dsd_col_done
    lb   t4, 0(a0)
    beqz t4, dsd_skip
    sb   t4, 0(t5)
dsd_skip:
    addi a0, a0, 1
    addi t5, t5, 1
    addi t6, t6, 1
    j    dsd_col
dsd_col_done:
    addi t0, t0, 320
    addi t3, t3, 1
    j    dsd_row
dsd_row_done:
    ret

#########################################################################
# draw_powerups / draw_powerup
# Item = quadrado 14x14 solido, cor conforme o tipo (placeholder).
#########################################################################
draw_powerups:
    addi sp, sp, -12
    sw   ra, 8(sp)
    sw   s1, 4(sp)
    sw   s2, 0(sp)
    la   s1, powerups
    li   s2, MAX_POWERUPS
dp_loop:
    beqz s2, dp_fim
    lw   t0, 8(s1)
    beqz t0, dp_next
    lw   a1, 0(s1)                 # x
    lw   a2, 4(s1)                 # y
    lw   a3, 12(s1)                # tipo
    jal  draw_powerup
dp_next:
    addi s1, s1, TAM_POWERUP
    addi s2, s2, -1
    j    dp_loop
dp_fim:
    lw   ra, 8(sp)
    lw   s1, 4(sp)
    lw   s2, 0(sp)
    addi sp, sp, 12
    ret

# a1 = x, a2 = y, a3 = tipo -> desenha a textura 20x20 do tipo
draw_powerup:
    la   a0, tex_coracao           # default: coracao
    li   t1, PU_TRIPLO
    bne  a3, t1, dpu_t1
    la   a0, tex_triplo
dpu_t1:
    li   t1, PU_ESCUDO
    bne  a3, t1, dpu_t2
    la   a0, tex_escudo
dpu_t2:
    j    draw_tex20                # a0=textura, a1=x, a2=y (tail call)

#########################################################################
# draw_tex20 (a0 = textura com header .word 20,20 ; a1 = x ; a2 = y)
# Desenha um sprite 20x20, 0x00 = transparente. Rotina folha.
#########################################################################
draw_tex20:
    la   t0, base_frame_A
    lw   s0, 0(t0)
    addi a0, a0, 8                 # pula header (2 words)
    li   t1, 320
    mul  t2, a2, t1
    add  t2, t2, a1
    add  t0, s0, t2
    li   t3, 0
dt20_row:
    li   t4, 20
    beq  t3, t4, dt20_done
    mv   t5, t0
    li   t6, 0
dt20_col:
    li   t4, 20
    beq  t6, t4, dt20_col_done
    lb   t4, 0(a0)
    beqz t4, dt20_skip
    sb   t4, 0(t5)
dt20_skip:
    addi a0, a0, 1
    addi t5, t5, 1
    addi t6, t6, 1
    j    dt20_col
dt20_col_done:
    addi t0, t0, 320
    addi t3, t3, 1
    j    dt20_row
dt20_done:
    ret

#########################################################################
# draw_escudo_aura — enquanto o escudo estiver ativo, desenha o icone do
# escudo piscando sobre o mago, sinalizando a imunidade.
#########################################################################
draw_escudo_aura:
    la   t0, escudo_timer
    lw   t0, 0(t0)
    blez t0, dea_fim
    andi t1, t0, 8                 # pisca (~a cada 8 frames)
    beqz t1, dea_fim
    la   t0, posicao_x_mago
    lw   a1, 0(t0)
    addi a1, a1, 2                 # centraliza escudo 20x20 no mago 24x24
    la   t0, posicao_y_mago
    lw   a2, 0(t0)
    addi a2, a2, 2
    la   a0, tex_escudo
    j    draw_tex20                # tail call (draw_tex20 retorna pro chamador)
dea_fim:
    ret
