-- =====================================================================================
--  ARQUIVO 5:  AS CINCO PERGUNTAS DE NEGOCIO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 04-fato.sql
--
--  Cada pergunta e UMA consulta: um SELECT com JOIN e GROUP BY. A subconsulta
--  aparece na P2 e na P5, e serve para trazer o total da rede como denominador.
-- =====================================================================================

USE dw_pata_amiga;

-- =====================================================================================
--  P1 - ONDE ESTA O GARGALO DO PROCESSO DE ENTREGA?
-- =====================================================================================
--  Media (AVG) dos quatro intervalos ja calculados na carga, agrupada por porte
--  de loja. AVG ignora NULL - por isso a etapa nao cumprida foi gravada como NULL.
--  dias_total_ate_entrega e o processo inteiro, nao um dos quatro intervalos.

-- >>> ESCREVA AQUI a consulta da P1
SELECT
    dl.porte,
    ROUND(AVG(fp.dias_integracao_separacao), 2) AS media_integracao_separacao,
    ROUND(AVG(fp.dias_separacao_nota), 2) AS media_separacao_nota,
    ROUND(AVG(fp.dias_nota_despacho), 2) AS media_nota_despacho,
    ROUND(AVG(fp.dias_despacho_entrega), 2) AS media_despacho_entrega,
    ROUND(AVG(fp.dias_total_ate_entrega), 2) AS media_total_ate_entrega
FROM fato_pedido fp
INNER JOIN dim_loja dl
    ON fp.sk_loja = dl.sk_loja
WHERE fp.sk_loja <> -1
GROUP BY dl.porte
ORDER BY dl.porte;


-- =====================================================================================
--  P2 - QUAL CATEGORIA CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_categoria. Agrupe pelo nome_categoria
--  PADRONIZADO (nunca pela grafia crua). O percentual do total usa uma
--  subconsulta com o faturamento da rede como denominador.

-- >>> ESCREVA AQUI a consulta da P2
SELECT
    dc.nome_categoria,
    ROUND(SUM(fp.vl_liquido), 2) AS faturamento,
    ROUND(
        SUM(fp.vl_liquido) /
        (
            SELECT SUM(vl_liquido)
            FROM fato_pedido
        ) * 100,
        2
    ) AS percentual_total
FROM fato_pedido fp
INNER JOIN dim_categoria dc
    ON fp.sk_categoria = dc.sk_categoria
WHERE fp.vl_liquido IS NOT NULL
  AND fp.sk_categoria <> -1
GROUP BY dc.nome_categoria
ORDER BY faturamento DESC;

-- =====================================================================================
--  P3 - O DESCONTO FUNCIONA IGUAL EM TODO CANAL?
-- =====================================================================================
--  Aqui NAO ha JOIN: desconto e canal foram padronizados na carga e moram na
--  propria fato. Compare o TICKET MEDIO com e sem desconto DENTRO de cada canal.
--  Confira se o WhatsApp aparece - se nao, o CASE do arquivo 04 testou APP antes
--  de WHATS.

-- >>> ESCREVA AQUI a consulta da P3
SELECT
    canal_pedido,
    houve_desconto,
    COUNT(*) AS quantidade_pedidos,
    ROUND(AVG(vl_liquido), 2) AS ticket_medio
FROM fato_pedido
WHERE vl_liquido IS NOT NULL
GROUP BY
    canal_pedido,
    houve_desconto
ORDER BY
    canal_pedido,
    houve_desconto;


-- =====================================================================================
--  P4 - QUAL PRACA DE ATENDIMENTO CONCENTRA O FATURAMENTO?
-- =====================================================================================
--  Esta e a pergunta que paga a dim_praca e a ponte.
--  Caminho: fato_pedido -> dim_loja -> bridge_loja_praca -> dim_praca (a ponte
--  entra pelo cod_loja). O JOIN com a ponte DUPLICA a linha do pedido, uma por
--  praca - isso esta certo. Multiplique por b.fator_publico para o faturamento
--  nao ser contado duas vezes.

-- >>> ESCREVA AQUI a consulta da P4
SELECT
    dp.cod_praca,
    dp.nome_praca,
    dp.regional,
    ROUND(
        SUM(fp.vl_liquido * b.fator_publico),
        2
    ) AS faturamento_rateado
FROM fato_pedido fp

INNER JOIN dim_loja dl
    ON fp.sk_loja = dl.sk_loja

INNER JOIN bridge_loja_praca b
    ON dl.cod_loja = b.cod_loja

INNER JOIN dim_praca dp
    ON b.sk_praca = dp.sk_praca

WHERE fp.sk_loja <> -1
  AND fp.vl_liquido IS NOT NULL

GROUP BY
    dp.cod_praca,
    dp.nome_praca,
    dp.regional

ORDER BY faturamento_rateado DESC;

-- =====================================================================================
--  P5 - ONDE ABRIR A PROXIMA LOJA, E O QUE OS DADOS NAO PERMITEM AFIRMAR?
-- =====================================================================================
--  (a) Ranqueie as lojas por itens POR MIL HABITANTES (numerador na fato,
--      denominador na dimensao), calculado AQUI na consulta - nunca gravado
--      pronto. Cruze com o tempo medio de entrega.
--  (b) Mostre o faturamento por faixa de franquia e explique por que ele NAO
--      responde "quanto veio de lojas que JA ERAM Ouro na data do pedido": o
--      cadastro so tem a foto de hoje.
--  (c) Meca o que ficou de fora: pedidos sem loja, entregas nao concluidas,
--      itens e valores em branco.

-- >>> ESCREVA AQUI as consultas da P5
-- P5(a)

SELECT
    dl.cod_loja,
    dl.nome_loja,
    dl.cidade,
    dl.porte,
    dl.populacao_cidade,
    SUM(fp.qt_itens) AS total_itens,
    ROUND(
        SUM(fp.qt_itens) / dl.populacao_cidade * 1000,
        2
    ) AS itens_por_mil_habitantes,
    ROUND(
        AVG(fp.dias_total_ate_entrega),
        2
    ) AS media_dias_entrega
FROM fato_pedido fp
INNER JOIN dim_loja dl
    ON fp.sk_loja = dl.sk_loja
WHERE fp.sk_loja <> -1
  AND dl.populacao_cidade IS NOT NULL
  AND dl.populacao_cidade > 0
GROUP BY
    dl.cod_loja,
    dl.nome_loja,
    dl.cidade,
    dl.porte,
    dl.populacao_cidade
ORDER BY itens_por_mil_habitantes DESC;

-- P5(b)
SELECT
    dl.faixa_franquia,
    COUNT(DISTINCT fp.numero_pedido) AS quantidade_pedidos,
    ROUND(SUM(fp.vl_liquido), 2) AS faturamento
FROM fato_pedido fp
INNER JOIN dim_loja dl
    ON fp.sk_loja = dl.sk_loja
WHERE fp.sk_loja <> -1
  AND fp.vl_liquido IS NOT NULL
GROUP BY dl.faixa_franquia
ORDER BY faturamento DESC;

-- P5(c)
SELECT
    'Pedidos sem loja' AS indicador,
    COUNT(*) AS quantidade
FROM fato_pedido
WHERE sk_loja = -1

UNION ALL

SELECT
    'Entregas nao concluidas' AS indicador,
    COUNT(*) AS quantidade
FROM fato_pedido
WHERE sk_tempo_entrega = -1

UNION ALL

SELECT
    'Itens em branco' AS indicador,
    COUNT(*) AS quantidade
FROM fato_pedido
WHERE qt_itens IS NULL

UNION ALL

SELECT
    'Valores em branco' AS indicador,
    COUNT(*) AS quantidade
FROM fato_pedido
WHERE vl_liquido IS NULL;