-- =====================================================================================
--  ARQUIVO 4:  A TABELA FATO
--  Case: Pata Amiga - rede de petshops de SC  |  MySQL 8.0
-- =====================================================================================
--  Rode depois de: 03-dimensoes.sql
--
--  UMA fato, UM unico INSERT ... SELECT. A tabela ja existe, vazia (arquivo 02).
--  4.044 linhas = 4.044 pedidos.
--
--  Regra geral: a limpeza dos dados fica nas dimensoes; a fato apenas procura a
--  linha correta (por JOIN). Nenhuma FK fica nula: quando o dado falta, ela
--  aponta para a linha -1 (CASE WHEN ... IS NULL THEN -1).
--
--  Sugestao: comece pelo esqueleto (numero_pedido + as duas FKs de tempo +
--  FROM), rode e confira 4.044 linhas; depois acrescente as colunas aos poucos.
-- =====================================================================================

USE dw_pata_amiga;

SELECT
    p.NumeroPedido AS numero_pedido,

    CAST(
        DATE_FORMAT(
            STR_TO_DATE(p.DtHoraPedido, '%m/%d/%Y %h:%i %p'),
            '%Y%m%d'
        ) AS SIGNED
    ) AS sk_tempo_pedido,

    CASE
        WHEN TRIM(p.DtEntregaCliente) = ''
            THEN -1
        ELSE CAST(
            DATE_FORMAT(
                DATE(p.DtEntregaCliente),
                '%Y%m%d'
            ) AS SIGNED
        )
    END AS sk_tempo_entrega

FROM stg_pedido p;


SELECT COUNT(*) AS quantidade_pedidos
FROM stg_pedido;

-- >>> ESCREVA AQUI o INSERT INTO fato_pedido (...) SELECT ... FROM stg_pedido ...

USE dw_pata_amiga;

INSERT INTO fato_pedido
(
    numero_pedido,
    sk_tempo_pedido,
    sk_tempo_entrega,
    sk_loja,
    sk_categoria,
    houve_desconto,
    canal_pedido,
    dt_pedido,
    qt_itens,
    vl_liquido,
    dias_integracao_separacao,
    dias_separacao_nota,
    dias_nota_despacho,
    dias_despacho_entrega,
    dias_total_ate_entrega
)
SELECT

    -- PEDIDO
    p.NumeroPedido,

    -- TEMPO DO PEDIDO
    CAST(
        DATE_FORMAT(
            STR_TO_DATE(
                p.DtHoraPedido,
                '%m/%d/%Y %h:%i %p'
            ),
            '%Y%m%d'
        ) AS SIGNED
    ),

    -- TEMPO DA ENTREGA
    CASE
        WHEN TRIM(p.DtEntregaCliente) = ''
            THEN -1
        ELSE CAST(
            DATE_FORMAT(
                DATE(p.DtEntregaCliente),
                '%Y%m%d'
            ) AS SIGNED
        )
    END,

    -- LOJA
    CASE
        WHEN dl.sk_loja IS NULL THEN -1
        ELSE dl.sk_loja
    END,

    -- CATEGORIA
    CASE
        WHEN dc.sk_categoria IS NULL THEN -1
        ELSE dc.sk_categoria
    END,

    -- DESCONTO
    CASE
        WHEN UPPER(TRIM(p.HouveDesconto)) IN
             ('S','SIM','1','X','TRUE','V')
            THEN 'Sim'

        WHEN UPPER(TRIM(p.HouveDesconto)) IN
             ('N','NAO','0','FALSE','F')
            THEN 'Nao'

        ELSE 'Nao Informado'
    END,

    -- CANAL
    CASE
        WHEN UPPER(TRIM(p.CanalPedido)) LIKE '%WHATS%'
            THEN 'WhatsApp'

        WHEN UPPER(TRIM(p.CanalPedido)) LIKE '%APP%'
            THEN 'App'

        WHEN UPPER(TRIM(p.CanalPedido)) LIKE '%SITE%'
            THEN 'Site'

        WHEN UPPER(TRIM(p.CanalPedido)) LIKE '%LOJA%'
            THEN 'Loja Fisica'

        WHEN UPPER(TRIM(p.CanalPedido)) LIKE '%TEL%'
            THEN 'Telefone'

        ELSE 'Nao Informado'
    END,

    -- DATA/HORA DO PEDIDO
    STR_TO_DATE(
        p.DtHoraPedido,
        '%m/%d/%Y %h:%i %p'
    ),

    -- QUANTIDADE DE ITENS
    CASE
        WHEN TRIM(p.`QTD.Itens`) IN ('', '-')
            THEN NULL
        ELSE CAST(
            REPLACE(TRIM(p.`QTD.Itens`), '.', '')
            AS SIGNED
        )
    END,

    -- VALOR LÍQUIDO
    CASE
    WHEN TRIM(p.`ValorLiquidoPedido(R$)`) IN ('', '-')
        THEN NULL

    WHEN TRIM(p.`ValorLiquidoPedido(R$)`) LIKE 'R$%'
        THEN CAST(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            TRIM(p.`ValorLiquidoPedido(R$)`),
                            'R$', ''
                        ),
                        ' ', ''
                    ),
                    '.', ''
                ),
                ',', '.'
            ) AS DECIMAL(15,2)
        )

    WHEN TRIM(p.`ValorLiquidoPedido(R$)`) LIKE '%,%'
        THEN CAST(
            REPLACE(
                REPLACE(
                    TRIM(p.`ValorLiquidoPedido(R$)`),
                    '.', ''
                ),
                ',', '.'
            ) AS DECIMAL(15,2)
        )

    WHEN TRIM(p.`ValorLiquidoPedido(R$)`) LIKE '%.%'
        THEN CAST(
            TRIM(p.`ValorLiquidoPedido(R$)`)
            AS DECIMAL(15,2)
        )

    ELSE CAST(
        TRIM(p.`ValorLiquidoPedido(R$)`)
        AS DECIMAL(15,2)
    )
END,

    -- INTEGRAÇÃO → SEPARAÇÃO
    CASE
        WHEN TRIM(p.DtHoraIntegracaoERP) = ''
          OR TRIM(p.`Dt Separacao Estoque`) = ''
            THEN NULL
        ELSE DATEDIFF(
            DATE(p.`Dt Separacao Estoque`),
            DATE(
                STR_TO_DATE(
                    p.DtHoraIntegracaoERP,
                    '%m/%d/%Y %h:%i %p'
                )
            )
        )
    END,

    -- SEPARAÇÃO → NOTA
    CASE
        WHEN TRIM(p.`Dt Separacao Estoque`) = ''
          OR TRIM(p.DtNotaFiscal) = ''
            THEN NULL
        ELSE DATEDIFF(
            DATE(p.DtNotaFiscal),
            DATE(p.`Dt Separacao Estoque`)
        )
    END,

    -- NOTA → DESPACHO
    CASE
        WHEN TRIM(p.DtNotaFiscal) = ''
          OR TRIM(p.Dt_Despacho_Transportadora) = ''
            THEN NULL
        ELSE DATEDIFF(
            DATE(p.Dt_Despacho_Transportadora),
            DATE(p.DtNotaFiscal)
        )
    END,

    -- DESPACHO → ENTREGA
    CASE
        WHEN TRIM(p.Dt_Despacho_Transportadora) = ''
          OR TRIM(p.DtEntregaCliente) = ''
            THEN NULL
        ELSE DATEDIFF(
            DATE(p.DtEntregaCliente),
            DATE(p.Dt_Despacho_Transportadora)
        )
    END,

    -- INTEGRAÇÃO → ENTREGA
    CASE
        WHEN TRIM(p.DtHoraIntegracaoERP) = ''
          OR TRIM(p.DtEntregaCliente) = ''
            THEN NULL
        ELSE DATEDIFF(
            DATE(p.DtEntregaCliente),
            DATE(
                STR_TO_DATE(
                    p.DtHoraIntegracaoERP,
                    '%m/%d/%Y %h:%i %p'
                )
            )
        )
    END

FROM stg_pedido p

-- LOJA
LEFT JOIN dim_loja dl
    ON dl.chave_loja =
       TRIM(
           REPLACE(
               REPLACE(
                   CASE
                       WHEN TRIM(p.`Loja-Nome`) =
                            'PATA AMIGA BLUMENAL CENTRO'
                           THEN 'PATA AMIGA BLUMENAU CENTRO'

                       WHEN TRIM(p.`Loja-Nome`) =
                            'PATA AMIGA FLORIPA NORTE'
                           THEN 'PATA AMIGA FLORIANOPOLIS NORTE'

                       WHEN TRIM(p.`Loja-Nome`) =
                            'PATA AMIGA JGUA DO SUL'
                           THEN 'PATA AMIGA JARAGUA DO SUL'

                       ELSE TRIM(p.`Loja-Nome`)
                   END,
                   '/SC',
                   ''
               ),
               '  ',
               ' '
           )
       )

-- CATEGORIA
LEFT JOIN dim_categoria dc
    ON dc.categoria_origem = TRIM(p.CategoriaProduto);
    
    USE dw_pata_amiga;

SELECT COUNT(*) AS quantidade
FROM fato_pedido;
--
--  Roteiro das colunas:
--
--  * sk_tempo_pedido / sk_tempo_entrega: a chave e a data no formato AAAAMMDD.
--    Monte com CAST(DATE_FORMAT(<a data>, '%Y%m%d') AS SIGNED). A data do PEDIDO
--    vem no formato americano com AM/PM: a mascara e '%m/%d/%Y %h:%i %p'
--    (STR_TO_DATE). Usar '%d/%m/%Y' NAO da erro - ela devolve NULL e datas
--    erradas em silencio, que e pior. Os marcos da entrega ja vem em ISO:
--    DATE() basta. Entrega em branco -> -1.
--
--  * sk_loja, sk_categoria: vem de LEFT JOIN; se nao achou par, -1.
--
--  * LOJA (LEFT JOIN dim_loja): limpe o nome no ON. REPLACE tira '/SC' e o espaco
--    duplo; um CASE resolve 3 grafias (digitacao, apelido, abreviacao). Acento e
--    maiuscula nao atrapalham: a collation padrao do MySQL trata 'Timbo', 'TIMBO'
--    e 'Timbo' com acento como o mesmo texto.
--
--  * CATEGORIA (LEFT JOIN dim_categoria): uma linha so -
--    ON dc.categoria_origem = p.`CategoriaProduto`.
--
--  * houve_desconto e canal_pedido: padronize com CASE e grave na PROPRIA fato
--    (nao ha dimensao para eles). O de-para completo dos dois campos esta no
--    ENUNCIADO, na secao 7 ("Como padronizar o desconto e o canal").
--    A ordem importa: 'WHATSAPP' contem 'APP',
--    entao teste WHATS antes de APP.
--
--  * dinheiro e itens: '' e '-' viram NULL; tire "R$" e trate o milhar.
--
--  * os lags em dias: DATEDIFF(<fim>, <inicio>). Etapa nao cumprida grava NULL,
--    nunca 0. Use DATE() em volta da integracao (ela tem hora).

-- =====================================================================================
--  Confira o resultado com o 00-conferencia.sql (bloco "DEPOIS DO 04").
-- =====================================================================================

DESCRIBE dim_loja;

