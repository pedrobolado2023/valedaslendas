"""
Animações próprias de cada skill (uma por skill ativa, com o nome "sk_<id>" de GameData.SKILLS).
Cada função devolve {nome: (quadros, fn(t) -> pose, loop)}; a pose soma por cima da pose parada da classe.
O jogo (player.gd: play_skill) toca "sk_<id>" quando a skill é usada; sem ela, cai no ataque normal.
Sinais dos eixos: ver o comentário em mpfb_kit.py (blocos para animações de skill). 24 quadros = 1 segundo.
"""
import math

from mathutils import Vector

import mpfb_kit as K

X, Y, Z = K.WX, K.WY, K.WZ
ease, pulse, crouch, merge = K.ease, K.pulse, K.crouch, K.merge
sin, tau = math.sin, math.tau


def V(x=0.0, y=0.0, z=0.0):
    return Vector((x, y, z))


# =================================================================== DRUIDA (cajado em pé na mão direita)

def druida():
    def roots(t):
        # Chamado das Raízes: ergue o cajado e crava no chão, agachando
        up = pulse(t, 0.0, 0.3, 0.35, 0.5)
        hit = pulse(t, 0.35, 0.5, 0.7, 1.0)
        return merge(crouch(0.6 * hit, 0.1 * hit), {
            "upperarm_r": [(X, -0.9 * up + 0.35 * hit)], "lowerarm_r": [(X, -0.3 * up + 0.2 * hit)],
            "upperarm_l": [(X, -0.5 * hit), (Y, -0.4 * hit)], "lowerarm_l": [(X, -0.3 * hit)],
            "spine_03": [(X, -0.1 * up + 0.2 * hit)], "neck_01": [(X, -0.1 * up + 0.1 * hit)],
            "_loc": V(0, 0, 0.03 * up)})

    def bless(t):
        # Bênção da Flora: abre os braços para o céu e olha para cima
        k = pulse(t, 0.0, 0.35, 0.7, 1.0)
        return {"upperarm_l": [(X, -1.6 * k), (Y, -0.5 * k)], "lowerarm_l": [(X, 0.25 * k)],
                "upperarm_r": [(X, -0.6 * k), (Y, 0.4 * k)],
                "spine_01": [(X, -0.08 * k)], "spine_03": [(X, -0.12 * k)], "neck_01": [(X, -0.2 * k)], "head": [(X, -0.25 * k)],
                "_loc": V(0, 0, 0.03 * k)}

    def bark(t):
        # Casca de Carvalho: firma os pés, crava o cajado e cruza o braço na frente do peito
        k = pulse(t, 0.0, 0.25, 0.75, 1.0)
        shake = 0.03 * sin(t * tau * 6) * k
        return merge(crouch(0.45 * k), {
            "upperarm_l": [(X, -1.0 * k), (Y, 0.5 * k)], "lowerarm_l": [(X, -1.5 * k)],
            "upperarm_r": [(X, 0.15 * k)], "spine_03": [(X, 0.1 * k), (Z, shake)], "head": [(X, 0.12 * k)]})

    def wind(t):
        # Fúria dos Ventos: varre o cajado na horizontal com o tronco girando e empurra o vento com a esquerda
        wind_up = pulse(t, 0.0, 0.3, 0.32, 0.5)
        sweep = pulse(t, 0.3, 0.5, 0.65, 1.0)
        return merge(crouch(0.25 * sweep), {
            "spine_01": [(Z, 0.35 * wind_up - 0.45 * sweep)], "spine_03": [(Z, 0.3 * wind_up - 0.4 * sweep)],
            "upperarm_r": [(X, -1.1 * (wind_up + sweep)), (Y, 0.6 * wind_up - 0.3 * sweep)], "lowerarm_r": [(X, 0.5 * sweep)],
            "upperarm_l": [(X, -1.3 * sweep)], "lowerarm_l": [(X, 0.3 * sweep)],
            "head": [(Z, -0.2 * wind_up + 0.2 * sweep)]})

    def awaken(t):
        # Despertar Lendário: junta força agachada, salta com os braços abertos e aterrissa batendo o cajado
        gather = pulse(t, 0.0, 0.25, 0.3, 0.4)
        rise = pulse(t, 0.3, 0.45, 0.55, 0.68)
        land = pulse(t, 0.62, 0.72, 0.85, 1.0)
        return merge(crouch(0.6 * gather + 0.7 * land), {
            "upperarm_l": [(X, -2.0 * rise - 0.3 * gather), (Y, -0.6 * rise)], "lowerarm_l": [(X, 0.3 * rise)],
            "upperarm_r": [(X, -1.6 * rise + 0.3 * land), (Y, 0.4 * rise)], "lowerarm_r": [(X, 0.4 * rise)],
            "spine_03": [(X, -0.2 * rise + 0.2 * gather + 0.15 * land)], "neck_01": [(X, -0.25 * rise)],
            "thigh_l": [(X, -0.3 * rise)], "calf_l": [(X, 0.5 * rise)], "thigh_r": [(X, 0.1 * rise)], "calf_r": [(X, 0.4 * rise)],
            "_loc": V(0, 0, 0.35 * rise)})

    def hail(t):
        # Granizo Ancestral: ergue o cajado ao céu chamando o gelo e aponta para a área
        call = pulse(t, 0.0, 0.3, 0.45, 0.6)
        point = pulse(t, 0.5, 0.65, 0.8, 1.0)
        return {"upperarm_r": [(X, -2.0 * call - 0.9 * point), (Y, 0.3 * call)], "lowerarm_r": [(X, 0.4 * call + 0.3 * point)],
                "upperarm_l": [(X, -1.4 * call - 1.1 * point), (Y, -0.4 * call)], "lowerarm_l": [(X, 0.2 * call + 0.4 * point)],
                "spine_03": [(X, -0.15 * call + 0.1 * point)], "neck_01": [(X, -0.25 * call + 0.1 * point)], "head": [(X, -0.2 * call)],
                "_loc": V(0, 0, 0.03 * call)}

    def thunder(t):
        # Fúria do Trovão: cajado acima da cabeça, corpo arqueado para trás, depois aponta para frente com tudo
        up = pulse(t, 0.0, 0.3, 0.35, 0.48)
        strike = pulse(t, 0.4, 0.52, 0.7, 1.0)
        return merge(crouch(0.3 * strike, 0.1 * strike), {
            "upperarm_r": [(X, -2.3 * up - 1.2 * strike)], "lowerarm_r": [(X, 0.3 * up + 0.5 * strike)],
            "upperarm_l": [(X, -0.6 * up - 1.2 * strike), (Y, -0.5 * up)], "lowerarm_l": [(X, 0.5 * strike)],
            "spine_01": [(X, -0.12 * up + 0.1 * strike)], "spine_03": [(X, -0.15 * up + 0.15 * strike)],
            "neck_01": [(X, -0.25 * up)], "thigh_l": [(X, -0.35 * strike)], "thigh_r": [(X, 0.25 * strike)]})

    def meteors(t):
        # Chuva de Meteoros: canaliza com os dois braços erguidos, tremendo de força
        k = pulse(t, 0.0, 0.2, 0.8, 1.0)
        tremble = 0.04 * sin(t * tau * 9) * k
        return merge(crouch(0.25 * k), {
            "upperarm_r": [(X, -2.2 * k), (Y, 0.5 * k)], "lowerarm_r": [(X, 0.3 * k + tremble)],
            "upperarm_l": [(X, -2.2 * k), (Y, -0.5 * k)], "lowerarm_l": [(X, 0.3 * k - tremble)],
            "spine_03": [(X, -0.2 * k), (Z, tremble)], "neck_01": [(X, -0.3 * k)], "head": [(X, -0.15 * k)]})

    def stomp(t):
        # Pisão da Morte: ergue o joelho e pisa com o corpo todo (o chão abre aos 0,3 s ≈ t 0,3)
        lift = pulse(t, 0.0, 0.2, 0.22, 0.3)
        hit = pulse(t, 0.26, 0.32, 0.6, 1.0)
        return merge(crouch(0.75 * hit, 0.2 * hit), {
            "thigh_r": [(X, -1.4 * lift)], "calf_r": [(X, 1.5 * lift)], "foot_r": [(X, 0.3 * lift)],
            "thigh_l": [(X, -0.2 * lift)], "calf_l": [(X, 0.3 * lift)],
            "upperarm_r": [(X, -1.0 * lift + 0.2 * hit), (Y, 0.4 * lift)], "lowerarm_r": [(X, -0.3 * lift)],
            "upperarm_l": [(Y, -1.0 * lift - 0.6 * hit), (X, -0.3 * hit)], "lowerarm_l": [(X, -0.6 * lift)],
            "spine_03": [(X, -0.15 * lift + 0.3 * hit)], "neck_01": [(X, -0.1 * lift + 0.15 * hit)],
            "_loc": V(0, 0, 0.12 * lift)})

    return {"sk_dr1": (24, roots, False), "sk_dr2": (30, bless, False), "sk_dr4": (24, bark, False),
            "sk_dr5": (20, wind, False), "sk_dr6": (32, awaken, False), "sk_dr7": (24, hail, False),
            "sk_dr8": (18, thunder, False), "sk_dr9": (36, meteors, False), "sk_dr10": (24, stomp, False)}


# =================================================================== ASSASSINO (adaga em cada mão, guarda alta)

def assassino():
    def shadow_step(t):
        # Passo das Sombras: encolhe e dá o bote com as duas adagas
        coil = pulse(t, 0.0, 0.3, 0.32, 0.45)
        stab = pulse(t, 0.35, 0.5, 0.7, 1.0)
        return merge(crouch(0.7 * coil + 0.4 * stab, 0.2 * stab), {
            "upperarm_l": [(X, 0.3 * coil - 0.9 * stab)], "lowerarm_l": [(X, -0.3 * coil + 1.0 * stab)],
            "upperarm_r": [(X, 0.3 * coil - 0.9 * stab)], "lowerarm_r": [(X, -0.3 * coil + 1.0 * stab)],
            "spine_03": [(X, 0.15 * coil + 0.15 * stab)], "neck_01": [(X, -0.15 * stab)],
            "thigh_l": [(X, -0.4 * stab)], "thigh_r": [(X, 0.35 * stab)],
            "_loc": V(0, -0.15 * stab, 0)})

    def poison(t):
        # Adagas Envenenadas: cruza as lâminas na frente do rosto e abre num floreio
        cross = pulse(t, 0.0, 0.3, 0.45, 0.6)
        open_ = pulse(t, 0.5, 0.7, 0.8, 1.0)
        return {"upperarm_l": [(X, -0.5 * cross), (Y, 0.4 * cross - 0.7 * open_)], "lowerarm_l": [(X, -0.4 * cross + 0.5 * open_)],
                "upperarm_r": [(X, -0.5 * cross), (Y, -0.4 * cross + 0.7 * open_)], "lowerarm_r": [(X, -0.4 * cross + 0.5 * open_)],
                "spine_03": [(X, 0.08 * cross - 0.1 * open_)], "head": [(X, 0.1 * cross - 0.1 * open_)]}

    def stealth(t):
        # Camuflagem Sombria: abaixa até quase o chão e se fecha
        k = pulse(t, 0.0, 0.35, 0.75, 1.0)
        return merge(crouch(0.9 * k, 0.25 * k), {
            "upperarm_l": [(X, -0.3 * k), (Y, 0.4 * k)], "lowerarm_l": [(X, -0.5 * k)],
            "upperarm_r": [(X, -0.3 * k), (Y, -0.4 * k)], "lowerarm_r": [(X, -0.5 * k)],
            "neck_01": [(X, 0.25 * k)], "spine_03": [(X, 0.2 * k)]})

    def blades(t):
        # Dança das Lâminas: braços abertos girando, cortes alternados (o jogo gira o corpo junto)
        k = pulse(t, 0.0, 0.15, 0.85, 1.0)
        w = sin(t * tau * 2)
        return merge(crouch(0.3 * k), {
            "upperarm_l": [(Y, -0.9 * k), (X, (-0.4 + 0.5 * w) * k)], "lowerarm_l": [(X, 0.6 * k)],
            "upperarm_r": [(Y, 0.9 * k), (X, (-0.4 - 0.5 * w) * k)], "lowerarm_r": [(X, 0.6 * k)],
            "spine_03": [(Z, 0.25 * w * k)], "head": [(Z, -0.2 * w * k)]})

    def void(t):
        # Manto do Vazio: salta para trás em esquiva, braços em guarda
        k = pulse(t, 0.0, 0.3, 0.55, 1.0)
        air = pulse(t, 0.05, 0.25, 0.35, 0.55)
        return merge(crouch(0.35 * k, -0.2 * k), {
            "upperarm_l": [(X, -0.5 * k)], "lowerarm_l": [(X, -0.6 * k)],
            "upperarm_r": [(X, -0.5 * k)], "lowerarm_r": [(X, -0.6 * k)],
            "spine_03": [(X, -0.15 * k)], "thigh_l": [(X, -0.3 * air)], "calf_l": [(X, 0.4 * air)],
            "_loc": V(0, 0.25 * k, 0.15 * air)})

    def execute(t):
        # Execução Celestial: salta com as duas adagas acima da cabeça e crava para baixo
        up = pulse(t, 0.0, 0.35, 0.4, 0.55)
        strike = pulse(t, 0.45, 0.6, 0.75, 1.0)
        return merge(crouch(0.8 * strike, 0.3 * strike), {
            "upperarm_l": [(X, -2.4 * up - 0.6 * strike)], "lowerarm_l": [(X, -0.6 * up + 0.4 * strike)],
            "upperarm_r": [(X, -2.4 * up - 0.6 * strike)], "lowerarm_r": [(X, -0.6 * up + 0.4 * strike)],
            "spine_03": [(X, -0.2 * up + 0.3 * strike)], "neck_01": [(X, -0.2 * up + 0.1 * strike)],
            "thigh_l": [(X, -0.3 * up)], "calf_l": [(X, 0.6 * up)], "calf_r": [(X, 0.5 * up)],
            "_loc": V(0, -0.1 * strike, 0.4 * up)})

    def fan(t):
        # Leque de Adagas: cruza as adagas no peito e abre os dois braços arremessando
        load = pulse(t, 0.0, 0.3, 0.32, 0.42)
        throw = pulse(t, 0.36, 0.5, 0.65, 1.0)
        return merge(crouch(0.25 * throw), {
            "upperarm_l": [(X, -0.4 * load - 1.2 * throw), (Y, 0.5 * load - 0.6 * throw)], "lowerarm_l": [(X, -0.8 * load + 0.9 * throw)],
            "upperarm_r": [(X, -0.4 * load - 1.2 * throw), (Y, -0.5 * load + 0.6 * throw)], "lowerarm_r": [(X, -0.8 * load + 0.9 * throw)],
            "spine_03": [(X, 0.15 * load - 0.05 * throw)], "_loc": V(0, -0.06 * throw, 0)})

    def mark(t):
        # Marca da Morte: aponta a adaga para o alvo, a outra mão perto do rosto
        k = pulse(t, 0.0, 0.25, 0.7, 1.0)
        return {"upperarm_r": [(X, -1.4 * k)], "lowerarm_r": [(X, 1.0 * k)],
                "upperarm_l": [(X, -0.9 * k), (Y, 0.4 * k)], "lowerarm_l": [(X, -1.2 * k)],
                "spine_01": [(Z, -0.25 * k)], "spine_03": [(Z, -0.15 * k)], "head": [(Z, 0.2 * k)]}

    def clones(t):
        # Clones das Sombras: abaixa, cruza os braços e os abre de uma vez chamando as sombras
        cross = pulse(t, 0.0, 0.3, 0.35, 0.45)
        burst = pulse(t, 0.4, 0.55, 0.7, 1.0)
        return merge(crouch(0.6 * cross + 0.3 * burst, 0.15 * cross), {
            "upperarm_l": [(X, -0.6 * cross), (Y, 0.5 * cross - 1.1 * burst)], "lowerarm_l": [(X, -1.0 * cross + 0.5 * burst)],
            "upperarm_r": [(X, -0.6 * cross), (Y, -0.5 * cross + 1.1 * burst)], "lowerarm_r": [(X, -1.0 * cross + 0.5 * burst)],
            "spine_03": [(X, 0.2 * cross - 0.1 * burst)], "neck_01": [(X, 0.2 * cross - 0.2 * burst)]})

    def eclipse(t):
        # Eclipse Sangrento: ergue as adagas para o céu escurecido e depois gira cortando, bem baixo
        up = pulse(t, 0.0, 0.25, 0.3, 0.4)
        spin = pulse(t, 0.35, 0.45, 0.85, 1.0)
        w = sin(t * tau * 3)
        return merge(crouch(0.6 * spin, 0.15 * spin), {
            "upperarm_l": [(X, -2.3 * up + (-0.4 + 0.5 * w) * spin), (Y, -0.9 * spin)], "lowerarm_l": [(X, 0.4 * up + 0.5 * spin)],
            "upperarm_r": [(X, -2.3 * up + (-0.4 - 0.5 * w) * spin), (Y, 0.9 * spin)], "lowerarm_r": [(X, 0.4 * up + 0.5 * spin)],
            "spine_03": [(X, -0.2 * up), (Z, 0.3 * w * spin)], "neck_01": [(X, -0.25 * up)], "_loc": V(0, 0, 0.08 * up)})

    return {"sk_as1": (16, shadow_step, False), "sk_as2": (22, poison, False), "sk_as3": (20, stealth, False),
            "sk_as4": (20, blades, False), "sk_as5": (18, void, False), "sk_as6": (26, execute, False),
            "sk_as7": (16, fan, False), "sk_as8": (22, mark, False), "sk_as9": (22, clones, False),
            "sk_as10": (30, eclipse, False)}


# =================================================================== MECÂNICO (ferramenta na direita apontando p/ frente)

def mecanico():
    def throw(t):
        # Disparo de Chave: arremesso por cima do ombro
        back = pulse(t, 0.0, 0.35, 0.38, 0.5)
        fwd = pulse(t, 0.38, 0.52, 0.65, 1.0)
        return {"upperarm_r": [(X, -1.6 * back - 1.2 * fwd), (Y, 0.4 * back)], "lowerarm_r": [(X, -0.8 * back + 0.8 * fwd)],
                "upperarm_l": [(X, -0.9 * back + 0.3 * fwd)],
                "spine_01": [(Z, 0.3 * back - 0.3 * fwd), (X, -0.08 * back + 0.15 * fwd)], "spine_03": [(Z, 0.25 * back - 0.25 * fwd)],
                "thigh_l": [(X, -0.25 * fwd)], "thigh_r": [(X, 0.2 * fwd)], "_loc": V(0, -0.05 * fwd, 0)}

    def turret(t):
        # Torreta Automática: ajoelha e monta a torreta na frente
        k = pulse(t, 0.0, 0.3, 0.75, 1.0)
        tap = 0.15 * sin(t * tau * 4) * pulse(t, 0.3, 0.35, 0.65, 0.75)
        return merge(crouch(0.9 * k, 0.3 * k), {
            "upperarm_r": [(X, -0.3 * k + tap)], "lowerarm_r": [(X, 0.3 * k)],
            "upperarm_l": [(X, -0.9 * k)], "lowerarm_l": [(X, 0.2 * k)],
            "neck_01": [(X, 0.25 * k)]})

    def field(t):
        # Campo de Força Magnético: abre a base e empurra as duas mãos para a frente
        k = pulse(t, 0.0, 0.3, 0.7, 1.0)
        return merge(crouch(0.35 * k), {
            "upperarm_l": [(X, -1.3 * k), (Y, -0.2 * k)], "lowerarm_l": [(X, 0.3 * k)],
            "upperarm_r": [(X, -0.5 * k), (Y, 0.2 * k)], "lowerarm_r": [(X, 0.2 * k)],
            "spine_03": [(X, 0.05 * k)], "thigh_l": [(Y, 0.15 * k)], "thigh_r": [(Y, -0.15 * k)]})

    def drone(t):
        # Drone de Reparo: ergue a mão esquerda e solta o drone, olhando para cima
        k = pulse(t, 0.0, 0.35, 0.65, 1.0)
        return {"upperarm_l": [(X, -2.3 * k), (Y, -0.3 * k)], "lowerarm_l": [(X, 0.3 * k)],
                "neck_01": [(X, -0.2 * k)], "head": [(X, -0.3 * k), (Z, -0.15 * k)], "spine_03": [(X, -0.08 * k)]}

    def colossus(t):
        # Colosso de Ouro: concentra força com os braços dobrados e pisa forte (o golpe sai aos 0,35 s)
        flex = pulse(t, 0.0, 0.15, 0.22, 0.3)
        stomp = pulse(t, 0.26, 0.32, 0.5, 0.75)
        roar = pulse(t, 0.4, 0.55, 0.8, 1.0)
        return merge(crouch(0.4 * flex + 0.6 * stomp), {
            "upperarm_l": [(X, -0.6 * flex), (Y, -0.9 * flex - 1.0 * roar)], "lowerarm_l": [(X, -1.6 * flex)],
            "upperarm_r": [(X, -0.3 * flex), (Y, 0.7 * flex + 0.6 * roar)], "lowerarm_r": [(X, -0.9 * flex)],
            "spine_03": [(X, 0.2 * flex + 0.25 * stomp - 0.15 * roar)], "neck_01": [(X, -0.25 * roar)],
            "thigh_l": [(X, -0.6 * flex)], "calf_l": [(X, 0.8 * flex)],
            "_loc": V(0, 0, 0.05 * flex)})

    def missiles(t):
        # Enxame de Mísseis: ergue o braço esquerdo (lançador no pulso) e sofre o coice de cada disparo
        k = pulse(t, 0.0, 0.2, 0.8, 1.0)
        kick = 0.12 * abs(sin(t * tau * 3)) * pulse(t, 0.15, 0.25, 0.7, 0.8)
        return {"upperarm_l": [(X, -1.9 * k + kick), (Y, -0.2 * k)], "lowerarm_l": [(X, 0.2 * k)],
                "upperarm_r": [(X, 0.2 * k)], "spine_03": [(X, -0.12 * k + kick * 0.5)], "neck_01": [(X, -0.15 * k)],
                "_loc": V(0, kick * 0.3, 0)}

    def flamer(t):
        # Lança-Chamas: firma a base e segura a ferramenta para frente, tremendo com a força do jato
        k = pulse(t, 0.0, 0.1, 0.85, 1.0)
        shake = 0.04 * sin(t * tau * 14) * k
        return merge(crouch(0.35 * k, 0.1 * k), {
            "upperarm_r": [(X, -0.35 * k + shake)], "lowerarm_r": [(X, -0.15 * k)],
            "upperarm_l": [(X, -1.0 * k), (Y, 0.35 * k)], "lowerarm_l": [(X, -0.6 * k)],
            "thigh_l": [(X, -0.3 * k)], "thigh_r": [(X, 0.25 * k)], "spine_03": [(Z, shake)]})

    def orbital(t):
        # Bombardeio Orbital: leva a mão ao ouvido (rádio), depois aponta para o céu e para o alvo
        radio = pulse(t, 0.0, 0.15, 0.3, 0.4)
        sky = pulse(t, 0.35, 0.5, 0.6, 0.72)
        point = pulse(t, 0.65, 0.78, 0.9, 1.0)
        return {"upperarm_l": [(X, -0.9 * radio - 2.4 * sky - 1.3 * point), (Y, 0.7 * radio)],
                "lowerarm_l": [(X, -1.9 * radio + 0.3 * sky + 0.6 * point)],
                "head": [(Z, 0.25 * radio), (X, -0.35 * sky + 0.1 * point)], "neck_01": [(X, -0.15 * sky)]}

    def tesla(t):
        # Torre Tesla: ajoelha e bate a ferramenta no chão para fincar a torre
        k = pulse(t, 0.0, 0.3, 0.7, 1.0)
        bang = pulse(t, 0.25, 0.32, 0.45, 0.6)
        return merge(crouch(0.8 * k, 0.3 * k), {
            "upperarm_r": [(X, -1.5 * k + 1.1 * bang)], "lowerarm_r": [(X, -0.4 * k + 0.3 * bang)],
            "upperarm_l": [(X, -0.5 * k)], "neck_01": [(X, 0.2 * k)], "spine_03": [(X, 0.15 * bang)]})

    return {"sk_me1": (18, throw, False), "sk_me2": (28, turret, False), "sk_me3": (24, field, False),
            "sk_me5": (22, drone, False), "sk_me6": (30, colossus, False), "sk_me7": (24, missiles, False),
            "sk_me8": (38, flamer, False), "sk_me9": (30, orbital, False), "sk_me10": (24, tesla, False)}


# =================================================================== NÁUTICO (tridente na direita, pronto para estocar)

def nautico():
    def thrust(t):
        # Estocada do Tridente: puxa bem para trás e avança com tudo
        back = pulse(t, 0.0, 0.3, 0.32, 0.42)
        hit = pulse(t, 0.32, 0.45, 0.6, 1.0)
        return merge(crouch(0.4 * hit, 0.15 * hit), {
            "upperarm_r": [(X, 0.7 * back - 0.85 * hit), (Y, 0.15 * back)], "lowerarm_r": [(X, -0.6 * back + 0.7 * hit)],
            "upperarm_l": [(X, -0.5 * back + 0.3 * hit)],
            "spine_01": [(Z, -0.25 * back + 0.35 * hit)], "spine_03": [(Z, -0.2 * back + 0.3 * hit)],
            "thigh_l": [(X, -0.5 * hit)], "thigh_r": [(X, 0.4 * hit)], "_loc": V(0, 0.04 * back - 0.18 * hit, 0)})

    def current(t):
        # Correnteza Fluvial: gira o tridente num arco largo em volta do corpo (o jogo gira o corpo junto)
        k = pulse(t, 0.0, 0.2, 0.75, 1.0)
        a = sin(t * math.pi * 2 - 0.5)
        return merge(crouch(0.3 * k), {
            "upperarm_r": [(Y, 0.9 * k), (X, -0.6 * k * a)], "lowerarm_r": [(X, 0.4 * k)],
            "upperarm_l": [(Y, -0.7 * k)],
            "spine_03": [(Z, 0.35 * a * k)], "spine_01": [(Z, 0.2 * a * k)]})

    def shell(t):
        # Escudo de Conchas: crava o tridente, firma e levanta o braço esquerdo como escudo
        k = pulse(t, 0.0, 0.25, 0.75, 1.0)
        return merge(crouch(0.45 * k), {
            "upperarm_l": [(X, -1.2 * k), (Y, 0.4 * k)], "lowerarm_l": [(X, -1.4 * k)],
            "upperarm_r": [(X, 0.3 * k)], "lowerarm_r": [(X, -0.4 * k)],
            "spine_03": [(X, 0.1 * k)], "head": [(X, 0.1 * k)]})

    def companion(t):
        # Companheiro das Profundezas: ergue a mão esquerda chamando a criatura
        k = pulse(t, 0.0, 0.35, 0.7, 1.0)
        wave = 0.15 * sin(t * tau * 2) * k
        return {"upperarm_l": [(X, -2.2 * k), (Y, -0.4 * k)], "lowerarm_l": [(X, 0.2 * k + wave)],
                "neck_01": [(X, -0.15 * k)], "head": [(X, -0.2 * k), (Z, 0.2 * k)], "spine_03": [(X, -0.06 * k)]}

    def poseidon(t):
        # Fúria de Poseidon: ergue o tridente para o céu e crava no chão com um salto curto
        up = pulse(t, 0.0, 0.35, 0.45, 0.6)
        down = pulse(t, 0.5, 0.62, 0.8, 1.0)
        return merge(crouch(0.3 * up * 0 + 0.75 * down, 0.2 * down), {
            "upperarm_r": [(X, -2.0 * up + 0.2 * down), (Y, 0.3 * up)], "lowerarm_r": [(X, 0.6 * up + 0.3 * down)],
            "upperarm_l": [(X, -1.2 * up - 0.6 * down), (Y, -0.5 * up)], "lowerarm_l": [(X, 0.3 * up)],
            "spine_03": [(X, -0.2 * up + 0.3 * down)], "neck_01": [(X, -0.25 * up + 0.1 * down)],
            "_loc": V(0, 0, 0.25 * pulse(t, 0.3, 0.45, 0.5, 0.62))})

    return {"sk_na1": (16, thrust, False), "sk_na2": (20, current, False), "sk_na3": (22, shell, False),
            "sk_na5": (24, companion, False), "sk_na6": (32, poseidon, False)}
