# Tabela de Especificação Visual - Roteiro da Viagem (Ficha TFD)

Especificação milimétrica e tipográfica extraída a partir da análise direta do documento modelo (`CamScanner_11-10-2026_21_52.pdf`, formato A4: 210 x 297 mm / 595.28 x 841.89 pt).

---

## 1. Parâmetros Gerais da Página
- **Formato**: A4 (210,00 mm x 297,00 mm / 595,28 pt x 841,89 pt)
- **Orientação**: Retrato (Portrait)
- **Margem Esquerda**: 14,80 mm (~42,00 pt)
- **Margem Direita**: 14,80 mm (~42,00 pt) (Largura útil de conteúdo: ~180,40 mm / 511,28 pt)
- **Margem Superior**: 5,50 mm (~15,60 pt)
- **Margem Inferior**: 14,80 mm (~42,00 pt)
- **Família Tipográfica**: Helvetica (Sans-serif padrão PDF / ISO 32000-1)
- **Cores**: Monocromático (Preto `#000000` / escala de cinza neutra para linhas)

---

## 2. Cabeçalho Institucional (Repete em todas as páginas)

| Elemento | X (mm) | Y (mm) | X (pt) | Y (pt) | Largura (pt) | Fonte | Tamanho (pt) | Peso | Cor | Alinhamento |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Nome da Unidade** (`UNIDADE BASICA DE SAUDE DE POLONI`) | 54,97 | 5,50 | 155,80 | 15,60 | 283,68 | Helvetica | 15.0 | Bold | `#000000` | Centro |
| **Endereço/CNPJ/Fone** (`RUA ANTONIO MENDES, 140...`) | 27,60 | 11,18 | 78,24 | 31,68 | 438,80 | Helvetica | 7.5 | Regular | `#000000` | Centro |
| **Título do Documento** (`Roteiro da Viagem - Ficha de Atendimento TFD`) | 64,09 | 17,10 | 181,68 | 48,48 | 231,92 | Helvetica | 11.5 | Bold | `#000000` | Centro |

---

## 3. Bloco de Dados da Viagem (Repete em todas as páginas)

| Elemento | X (mm) | Y (mm) | X (pt) | Y (pt) | Largura (pt) | Fonte | Tamanho (pt) | Peso | Cor | Alinhamento |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Rótulo Motorista** | 14,90 | 22,86 | 42,24 | 64,80 | 80,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Valor Motorista** | 14,90 | 25,48 | 42,24 | 72,24 | 250,00 | Helvetica | 8.5 | Bold | `#000000` | Esquerda |
| **Rótulo Veículo** | 108,00 | 22,86 | 306,00 | 64,80 | 80,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Valor Veículo** | 108,00 | 25,48 | 306,00 | 72,24 | 135,00 | Helvetica | 8.5 | Regular | `#000000` | Esquerda |
| **Rótulo Saída** | 158,60 | 22,86 | 449,50 | 64,80 | 60,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Valor Saída** | 158,60 | 25,48 | 449,50 | 72,24 | 105,00 | Helvetica | 8.5 | Regular | `#000000` | Esquerda |
| **Rótulo Requisição** | 14,90 | 30,06 | 42,24 | 85,20 | 80,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Valor Requisição** | 14,90 | 32,85 | 42,24 | 93,12 | 80,00 | Helvetica | 8.5 | Regular | `#000000` | Esquerda |
| **Rótulo Destino Principal** | 45,30 | 30,06 | 128,40 | 85,20 | 120,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Valor Destino Principal** | 45,30 | 32,85 | 128,40 | 93,12 | 200,00 | Helvetica | 8.5 | Regular | `#000000` | Esquerda |

---

## 4. Subcabeçalho de Passageiros (Exclusivo da Página 1)

| Elemento | X (mm) | Y (mm) | X (pt) | Y (pt) | Largura (pt) | Fonte | Tamanho (pt) | Peso | Cor | Alinhamento |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Título Relação de Passageiros** | 84,50 | 37,93 | 239,52 | 107,52 | 119,76 | Helvetica | 11.5 | Bold | `#000000` | Centro |

---

## 5. Bloco de Cada Paciente / Passageiro (Repetitivo com Pitch de 50.7 pt / 17.9 mm)

*Para o paciente de índice $i$ na página ($i = 0, 1, 2, \dots$), a coordenada $Y$ base do bloco é:*  
$$Y_{\text{bloco}}(i) = Y_{\text{inicio}} + (i \times 50,70\,\text{pt})$$
*(Na Página 1, $Y_{\text{inicio}} = 123,84\,\text{pt}$ / $43,69\,\text{mm}$. Nas páginas seguintes sem o subtítulo "Relação de Passageiros", $Y_{\text{inicio}} = 107,50\,\text{pt}$ / $37,90\,\text{mm}$).*

### Linha 1 do Paciente (Identificação e Contato)
| Elemento | $\Delta X$ (pt) | $\Delta Y$ (pt) | Largura Máx (pt) | Fonte | Tamanho (pt) | Peso | Cor | Alinhamento |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Rótulo Paciente** | 42,24 | 0,00 | 80,00 | Helvetica | 5.5 | Regular | `#000000` | Esquerda |
| **Valor Nome Paciente** | 42,24 | 8,16 | 225,00 | Helvetica | 7.5 | Bold | `#000000` | Esquerda |
| **Rótulo Telefone** | 272,64 | 0,00 | 70,00 | Helvetica | 5.5 | Regular | `#000000` | Esquerda |
| **Valor Telefone** | 269,00 | 8,16 | 75,00 | Helvetica | 7.5 | Bold | `#000000` | Esquerda |
| **Rótulo Acompanhantes** | 348,48 | 0,00 | 80,00 | Helvetica | 5.5 | Regular | `#000000` | Esquerda |
| **Valor Acompanhante** | 348,72 | 8,16 | 145,00 | Helvetica | 7.5 | Regular | `#000000` | Esquerda |
| **Rótulo Tel. Acompanhante** | 497,28 | 0,00 | 90,00 | Helvetica | 5.5 | Regular | `#000000` | Esquerda |
| **Valor Tel. Acompanhante** | 497,28 | 8,16 | 90,00 | Helvetica | 7.5 | Regular | `#000000` | Esquerda |

### Linha 2 do Paciente (Endereço, Embarque e Destino)
| Elemento | $\Delta X$ (pt) | $\Delta Y$ (pt) | Largura Máx (pt) | Fonte | Tamanho (pt) | Peso | Cor | Alinhamento |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Rótulo Endereço** | 42,24 | 21,84 | 80,00 | Helvetica | 5.5 | Regular | `#000000` | Esquerda |
| **Valor Endereço** | 42,24 | 29,28 | 190,00 | Helvetica | 7.0 | Regular | `#000000` | Esquerda |
| **Rótulo Local de Saída** | 236,88 | 21,84 | 80,00 | Helvetica | 5.5 | Regular | `#000000` | Esquerda |
| **Valor Local de Saída** | 236,88 | 29,28 | 120,00 | Helvetica | 7.0 | Regular | `#000000` | Esquerda |
| **Rótulo Destino** | 360,24 | 21,84 | 80,00 | Helvetica | 5.5 | Regular | `#000000` | Esquerda |
| **Valor Destino** | 360,00 | 29,28 | 150,00 | Helvetica | 7.0 | Regular | `#000000` | Esquerda |
| **Rótulo Consulta** | 513,36 | 21,84 | 50,00 | Helvetica | 5.5 | Regular | `#000000` | Esquerda |
| **Valor Horário Consulta** | 513,36 | 29,28 | 65,00 | Helvetica | 7.0 | Regular | `#000000` | Esquerda |

---

## 6. Rodapé de Emissão (Exclusivo da Página 1)

| Elemento | X (pt) | Y (pt) | Largura (pt) | Fonte | Tamanho (pt) | Peso | Cor | Alinhamento |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Carimbo de Emissão** (`Emitido em DD/MM/AAAA HH:mm:ss`) | 400,00 | 722,15 | 150,00 | Helvetica | 7.0 | Regular | `#000000` | Direita |

---

## 7. Bloco de Resumo e Encerramento (Exclusivo da Última Página)

*Posicionado após o último paciente da folha final ou fixado no rodapé caso haja espaço livre:*

| Elemento | X (pt) | Y (pt) | Largura (pt) | Fonte | Tamanho (pt) | Peso | Cor | Alinhamento |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Título "Resumo"** | 282,96 | 336,00 | 60,00 | Helvetica | 10.5 | Bold | `#000000` | Centro |
| **Rótulo Total de Pacientes** | 31,20 | 349,20 | 65,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Valor Total de Pacientes** | 31,68 | 358,56 | 65,00 | Helvetica | 8.0 | Regular | `#000000` | Esquerda |
| **Rótulo Total de Acompanhantes**| 102,48 | 349,20 | 85,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Valor Total de Acompanhantes**| 102,72 | 358,32 | 85,00 | Helvetica | 8.0 | Regular | `#000000` | Esquerda |
| **Rótulo Total Geral** | 197,28 | 349,20 | 65,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Valor Total Geral** | 194,40 | 359,04 | 65,00 | Helvetica | 8.0 | Regular | `#000000` | Esquerda |
| **Rótulo Retorno** | 301,92 | 349,20 | 58,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Linha Retorno** (Traço de preenchimento) | 301,92 | 369,60 | 58,56 | Traço (0.75 pt) | — | — | `#000000` | — |
| **Rótulo Km Saída** | 370,56 | 349,20 | 59,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Linha Km Saída** | 370,56 | 369,60 | 59,04 | Traço (0.75 pt) | — | — | `#000000` | — |
| **Rótulo Km Retorno** | 439,92 | 349,20 | 59,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Linha Km Retorno** | 439,92 | 369,60 | 58,56 | Traço (0.75 pt) | — | — | `#000000` | — |
| **Rótulo Km Rodado** | 510,48 | 349,20 | 60,00 | Helvetica | 6.0 | Regular | `#000000` | Esquerda |
| **Linha Km Rodado** | 510,48 | 369,12 | 60,00 | Traço (0.75 pt) | — | — | `#000000` | — |
| **Linha de Assinatura** | 146,00 | 397,44 | 330,60 | Traço (0.75 pt) | — | — | `#000000` | Centro |
| **Rótulo Assinatura do Motorista**| 270,72 | 405,84 | 120,00 | Helvetica | 7.5 | Regular | `#000000` | Centro |
