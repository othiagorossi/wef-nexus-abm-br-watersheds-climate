# TASKS.md — WEF Nexus ABM

Controle operacional de tarefas técnicas.  
Para prazos e Gantt visual, ver `wef_nexus_cronograma.xlsx`.

---

## FASE 1 — Coleta de Dados e Estrutura ODD+D
**Prazo:** 14 de maio de 2026

### ANA
- [ ] Baixar shapefile de bacias hidrográficas (SNIRH)
- [ ] Baixar outorgas de uso da água por sub-bacia (CSV)
- [ ] Baixar projeções de disponibilidade hídrica até 2040 (relatório AdaptaBrasil)
- [ ] Documentar em `data/README_data.md`: URL, data de acesso, versão

### ANEEL
- [ ] Baixar dados de micro/minigeração distribuída solar por município (SIGEL/ANEEL)
- [ ] Filtrar para municípios da bacia de estudo
- [ ] Documentar em `data/README_data.md`

### MapBiomas
- [ ] Baixar coleção 9 (1985–2024) para a área da bacia — Google Earth Engine ou MapBiomas Plataforma
- [ ] Reclassificar classes de uso do solo relevantes (urbano, agropecuária, vegetação nativa)
  - Atenção: arquivos .tif grandes → não versionar no Git, usar script de download em `01_preprocess.R`
- [ ] Documentar em `data/README_data.md`

### IPCC AR6
- [ ] Baixar projeções SSP2-4.5 e SSP5-8.5 para precipitação e temperatura — região Sudeste BR
  - Fonte recomendada: IPCC WGI Interactive Atlas ou NASA NEX-GDDP-CMIP6
- [ ] Recortar para a bacia de estudo
- [ ] Documentar em `data/README_data.md`

### Bacia de estudo
- [ ] Definir e justificar a bacia selecionada (nome, estado, área km²)
- [ ] Atualizar README.md com a escolha final
- [ ] Inserir mapa de localização em `outputs/figures/`

### ODD+D
- [ ] Preencher seção Overview em `model/ODD+D.md`
- [ ] Preencher seção Design Concepts
- [ ] Rascunho da seção Details (completar após implementação)

---

## FASE 2 — Construção do ABM
**Prazo:** 4 de junho de 2026

### Agentes e regras
- [ ] Definir tipos de agentes: agricultor periurbano, consumidor residencial, prosumer solar, gestor hídrico
- [ ] Especificar atributos de cada agente (variáveis de estado)
- [ ] Especificar regras comportamentais por agente
  - Agricultor: decisão de irrigação (função do preço da água, disponibilidade hídrica, custo de energia)
  - Prosumer: decisão de adotar solar (função de custo de instalação, tarifa de energia, incentivo ANEEL)
  - Gestor hídrico: emissão/restrição de outorgas (função do estoque hídrico e demanda agregada)
- [ ] Documentar regras no ODD+D.md — seção Submodels

### Implementação NetLogo
- [ ] Criar `model/wef_nexus.nlogo` com estrutura inicial (setup / go / agentes)
- [ ] Implementar dinâmica hídrica (balanço simplificado por patch)
- [ ] Implementar adoção solar e efeito rebound no bombeamento
- [ ] Implementar transição de uso do solo (pressão urbana sobre AUP)
- [ ] Implementar cenários de governança (fragmentada vs. integrada)
- [ ] Documentar versão e extensões usadas em `model/environment.md`

### Testes
- [ ] Teste de unidade: balanço hídrico fechado sem agentes ativos
- [ ] Teste de sanidade: checar que aumento de prosumers → aumento de retirada de água
- [ ] Teste de sensibilidade inicial nos parâmetros principais

---

## FASE 3 — Calibração e Rodadas de Cenários
**Prazo:** 2 de julho de 2026

- [ ] Calibrar parâmetros com dados históricos (ANA + MapBiomas 1985–2005)
- [ ] Validar modelo com período 2005–2024 (out-of-sample)
- [ ] Rodar cenário S0 — baseline histórico
- [ ] Rodar cenário S1 — SSP2-4.5 / governança fragmentada
- [ ] Rodar cenário S2 — SSP5-8.5 / governança fragmentada
- [ ] Rodar cenário S3 — SSP2-4.5 / governança integrada
- [ ] Rodar cenário S4 — SSP5-8.5 / governança integrada
- [ ] Análise de sensibilidade (BehaviorSpace no NetLogo ou script R)
- [ ] Exportar outputs para `outputs/tables/`

---

## FASE 4 — Análise de Resultados
**Prazo:** 14 de julho de 2026

- [ ] Calcular índice composto WEF (água / energia / alimento) por cenário
- [ ] Identificar e quantificar o efeito rebound solar
- [ ] Identificar cascata de deslocamento de uso do solo
- [ ] Comparar falha de coordenação (fragmentada) vs. ganhos (integrada)
- [ ] Gerar todas as figuras do manuscrito em `04_figures.R` (300 DPI PDF)
  - Fig 1: Mapa da bacia de estudo
  - Fig 2: Dinâmica temporal do índice WEF por cenário
  - Fig 3: Efeito rebound solar — retirada de água vs. adoção GD
  - Fig 4: Transição de uso do solo por cenário
  - Fig 5: Análise de sensibilidade (heatmap ou tornado chart)

---

## FASE 5 — Redação do Manuscrito
**Prazo:** 18 de julho de 2026

- [ ] Introdução — contexto, gap, objetivo
- [ ] Materiais e Métodos — dados, ABM, cenários, ODD+D (suplementar)
- [ ] Resultados — narrativa dos 4 resultados emergentes
- [ ] Discussão — implicações de política pública, limitações
- [ ] Conclusão
- [ ] Referências (Zotero → BibTeX)
- [ ] Abstract final (ajustar com resultados reais)
- [ ] Revisão ortográfica e de estilo

---

## FASE 6 — Submissão
**Prazo:** 21 de julho de 2026

- [ ] Formatar manuscrito conforme template Water (MDPI)
- [ ] Verificar checklist de submissão MDPI
- [ ] Preparar Material Suplementar (ODD+D completo)
- [ ] Criar release v1.0.0 no GitHub → gerar DOI no Zenodo
- [ ] Inserir DOI Zenodo no manuscrito e no CITATION.cff
- [ ] Escrever cover letter
- [ ] Submeter pelo link fornecido pela editora

---

## Concluído ✅

- [x] Proposta de artigo enviada ao editor
- [x] Abstract finalizado
- [x] Waiver APC aprovado (100%)
- [x] Revisão de literatura preliminar (ABMs de nexo WEF)
- [x] Identificação do gap (Global South / periurbano / AUP)
- [x] Levantamento de fontes de dados públicos
- [x] Cronograma Kanban + Gantt (wef_nexus_cronograma.xlsx)
- [x] Estrutura do repositório FAIR (este repositório)
