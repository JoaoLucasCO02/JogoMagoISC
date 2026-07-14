.data
# Jingle original do menu, andamento ~129 BPM (mesmo da referencia menuInicial.mp3)
musica_menu_notas:     .byte  69, 72, 76, 74, 72, 71, 69, 64
musica_menu_duracoes:  .word 465,465,465,233,233,465,465,930
musica_menu_tam:       .word 8

.eqv INSTRUMENTO_8BIT    80    # Lead 1 (square) - musica do menu
.eqv INSTRUMENTO_IMPACTO 116   # Taiko Drum - disparo (parecido com hit.mp3)
.eqv INSTRUMENTO_GOBLIN  30    # Overdriven Guitar - sons do goblin
.eqv VELOCIDADE_NOTA     100
.eqv TECLA_AUDIO         0xff200004

.text

# Toca a musica do menu em loop, nota a nota, ate ESPACO ser pressionado.
# Cada nota e assincrona (nao trava o jogo) e o tempo entre notas usa o
# sleep_ms do arquivo principal; checa o teclado a cada nota p/ sair rapido.
tocar_musica_menu:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s1, 8(sp)
    sw s2, 4(sp)
    sw s3, 0(sp)

musica_menu_reinicia:
    la s1, musica_menu_notas
    la s2, musica_menu_duracoes
    la s3, musica_menu_tam
    lw s3, 0(s3)

musica_menu_nota:
    beqz s3, musica_menu_reinicia   # acabou a frase, toca de novo

    lb a0, 0(s1)
    lw a1, 0(s2)
    li a2, INSTRUMENTO_8BIT
    li a3, VELOCIDADE_NOTA
    li a7, 31                        # MIDI assincrono
    ecall

    mv a0, a1
    jal sleep_ms                     # espera a duracao da nota

    li t0, TECLA_AUDIO
    lw t1, 0(t0)
    li t2, ' '
    beq t1, t2, musica_menu_fim      # ESPACO pressionado: sai da musica

    addi s1, s1, 1
    addi s2, s2, 4
    addi s3, s3, -1
    j musica_menu_nota

musica_menu_fim:
    lw ra, 12(sp)
    lw s1, 8(sp)
    lw s2, 4(sp)
    lw s3, 0(sp)
    addi sp, sp, 16
    ret

# Som do disparo (parecido com hit.mp3: grave, curto, seco). Assincrono:
# dispara sem travar o jogo, pra nao atrapalhar tiros rapidos.
tocar_som_disparo:
    li a0, 43
    li a1, 150
    li a2, INSTRUMENTO_IMPACTO
    li a3, 120
    li a7, 31
    ecall
    ret

# Som do ogro atacando o mago (parecido com goblin_atack.mp3: rosnado curto).
# Sincrono (a3=33): so 2 notas rapidas, a pausa reforca o impacto do hit.
tocar_som_goblin_ataca:
    li a0, 50
    li a1, 150
    li a2, INSTRUMENTO_GOBLIN
    li a3, 110
    li a7, 33
    ecall

    li a0, 54
    li a1, 180
    li a2, INSTRUMENTO_GOBLIN
    li a3, 110
    li a7, 33
    ecall
    ret

# Som do ogro morrendo (parecido com goblin_morrendo.mp3: grito agudo caindo).
tocar_som_goblin_morre:
    li a0, 79
    li a1, 130
    li a2, INSTRUMENTO_GOBLIN
    li a3, 110
    li a7, 33
    ecall

    li a0, 74
    li a1, 130
    li a2, INSTRUMENTO_GOBLIN
    li a3, 100
    li a7, 33
    ecall

    li a0, 69
    li a1, 130
    li a2, INSTRUMENTO_GOBLIN
    li a3, 100
    li a7, 33
    ecall

    li a0, 64
    li a1, 250
    li a2, INSTRUMENTO_GOBLIN
    li a3, 90
    li a7, 33
    ecall
    ret
