# PROJET : ANALYSE STATISTIQUE DES ADMISSIONS ET INSCRIPTIONS
# - Objectif : Explorer, nettoyer et analyser les données d'admission et d'inscription.
# - Source : Jeu de données synthétique (12 extractions hebdomadaires du 31 août au 16 nov. 2026) avec anomalies pédagogiques.
# - Structure : Fichiers sources dans data/raw. Conservation des données dans (df) et création d'un tableau instantané final par demande (df_final).

# 1. PRÉPARATION DE L'ENVIRONNEMENT -------------------------------------


# - Installation unique requise si manquante :
# install.packages("dplyr")
# install.packages("ggplot2")

library(dplyr)
library(ggplot2)


# 2. IMPORTATION ET FUSION DES FICHIERS -----------------------------------

files <- list.files(
  "data/raw",
  pattern = "\\.csv$",
  full.names = TRUE
)

length(files)

data <- lapply(
  files,
  read.csv,
  stringsAsFactors = FALSE,
  na.strings = "NA"
)

df <- do.call(rbind, data)


# 3. EXPLORATION INITIALE DES DONNÉES -----------------------------------

length(files)
dim(df)
glimpse(df)

# Une même demande apparaît sur plusieurs semaines.


# 4. ÉVALUATION ET NETTOYAGE DE LA QUALITÉ DES DONNÉES --------------------

# 4.1. Identifier les valeurs manquantes

colSums(is.na(df))

# Majorité des NA concentrée dans processing_days (souvent structurel pour les dossiers non finalisés).
# À examiner par statut avant toute imputation.

# 4.2. Examiner les valeurs manquantes selon le statut

df |>
  mutate(delai_manquant = is.na(processing_days)) |>
  count(application_status, delai_manquant)

# Absences logiques pour "Submitted", "Under Review" et "Withdrawn".
# Anomalie : 12 lignes "Decision Issued" sans délai renseigné.

# 4.3. Examiner les délais manquants pour les décisions émises

delais_anormaux <- df |>
  filter(
    application_status == "Decision Issued",
    is.na(processing_days)
  )

View(delais_anormaux)

delais_anormaux |>
  summarise(
    nombre_observations = n(),
    demandes_distinctes = n_distinct(application_id)
  )

# 12 demandes distinctes concernées : conservation sans imputation (délai réel inconnu).

# 4.4. Rechercher les marqueurs textuels de valeurs manquantes

marqueurs_manquants <- c("", " ", "NULL", "NA", "N/A")

df |>
  summarise(
    across(
      where(is.character),
      ~ sum(trimws(.x) %in% marqueurs_manquants, na.rm = TRUE)
    )
  )

# Marqueurs textuels détectés dans "program" (215) et "application_channel" (170).


# 4.5. Harmoniser les marqueurs de valeurs manquantes

df <- df |>
  mutate(
    across(
      where(is.character),
      ~ {
        x <- trimws(.x)
        x[x %in% marqueurs_manquants] <- NA
        x
      }
    )
  )

colSums(is.na(df))

# Conversion effectuée en véritables "NA" (215 dans "program", 170 dans "application_channel"), sans imputation.


# 4.6. Détecter les doublons exacts

sum(duplicated(df))

# 4.7. Examiner les doublons exacts

doublons <- df |>
  filter(duplicated(df))

nrow(doublons)
head(doublons)

# 80 doublons exacts identifiés (à supprimer).

# 4.8. Supprimer les doublons exacts

df <- df |>
  distinct()

dim(df)
sum(duplicated(df))

# 80 doublons supprimés : reste 92 556 observations uniques et 12 variables.


# 4.9. Vérifier les variables temporelles

class(df$application_date)
class(df$weekly_snapshot)

head(df$application_date)
head(df$weekly_snapshot)

sort(unique(df$weekly_snapshot))

# Variables initialement en "character". 
# 12 extractions confirmées (31 août au 16 nov. 2026).


# 4.10. Vérifier les dates de candidature

dates_test <- as.Date(df$application_date, format = "%Y-%m-%d")

sum(is.na(dates_test))
unique(df$application_date[is.na(dates_test)])

# - Format AAAA-MM-JJ valide sur l'ensemble du jeu de données.

# 4.11. Convertir les variables temporelles

df <- df |>
  mutate(
    application_date = as.Date(application_date),
    weekly_snapshot = as.Date(weekly_snapshot)
  )

class(df$application_date)
class(df$weekly_snapshot)

summary(df$application_date)
summary(df$weekly_snapshot)

# Conversion au format "Date" réussie pour toutes les observations.


# 4.12. Examiner les modalités des variables qualitatives

unique(df$program)
unique(df$study_level)
unique(df$application_status)
unique(df$application_channel)

# Incohérences de casse repérées Business Administration et Online Portal.

# 4.13. Harmoniser les catégories qualitatives

df <- df |>
  mutate(
    program = case_when(
      tolower(trimws(program)) == "business administration" ~
        "Business Administration",
      TRUE ~ trimws(program)
    ),
    application_channel = case_when(
      tolower(trimws(application_channel)) == "online portal" ~
        "Online Portal",
      TRUE ~ trimws(application_channel)
    )
  )

unique(df$program)
unique(df$application_channel)

# Casse harmonisée : 10 programmes et 5 canaux distincts (NA conservés).

# 4.14. Examiner les combinaisons de statuts

df |>
  count(
    application_status,
    admission_decision,
    registration_status,
    sort = TRUE
  )

# Incohérences détectées : dossiers Rejected marqués Registered, et Decision Issued encore Pending.


# 4.15. Identifier les incohérences entre les statuts

anomalies_statuts <- df |>
  filter(
    (admission_decision == "Rejected" &
       registration_status == "Registered") |
      (admission_decision == "Pending" &
         application_status == "Decision Issued")
  )

View(anomalies_statuts)

anomalies_statuts |>
  summarise(
    nombre_observations = n(),
    demandes_distinctes = n_distinct(application_id)
  )

# 24 observations anormales correspondant à 13 demandes distinctes.


# 4.16. Répartition des anomalies par extraction hebdomadaire

anomalies_statuts |>
  count(weekly_snapshot, admission_decision, registration_status)

# Anomalies présentes sur les 12 semaines.
# Vérification par identifiant requise pour isoler les observations concernées.

# 4.17. Examiner les identifiants des demandes anormales

anomalies_statuts |>
  group_by(application_id) |>
  summarise(
    nombre_observations = n(),
    premiere_extraction = min(weekly_snapshot),
    derniere_extraction = max(weekly_snapshot),
    .groups = "drop"
  ) |>
  arrange(desc(nombre_observations))

# 1 cas persistant sur 12 semaines (APP000229) et 12 cas ponctuels.
# Aucune modification appliquée (données réelles impossibles à déduire).

# 4.18. Analyse descriptive des délais de traitement

summary(df$processing_days)

quantile(
  df$processing_days,
  probs = c(0.25, 0.50, 0.75),
  na.rm = TRUE
)

IQR(df$processing_days, na.rm = TRUE)

# Médiane : 13 jours | Moyenne : 15,45 jours | IQR : 12 jours (Q1=8, Q3=20).
# Asymétrie à droite: Étendue anormale de -4 à 165 jours.

# 4.19. Identifier et examiner les délais négatifs

df |>
  filter(!is.na(processing_days), processing_days < 0) |>
  summarise(
    nombre_observations = n(),
    demandes_distinctes = n_distinct(application_id),
    delai_minimum = min(processing_days)
  )

df |>
  filter(!is.na(processing_days), processing_days < 0) |>
  select(
    application_id,
    application_date,
    application_status,
    admission_decision,
    processing_days,
    weekly_snapshot
  ) |>
  arrange(processing_days)

# 12 demandes distinctes avec un délai de -4 jours (Decision Issued).
# À remplacer par NA sans supprimer les dossiers.

# 4.20. Corriger les délais négatifs

df <- df |>
  mutate(
    processing_days = ifelse(
      processing_days < 0,
      NA,
      processing_days
    )
  )

sum(df$processing_days < 0, na.rm = TRUE)
sum(is.na(df$processing_days))

# 12 délais négatifs passés en NA (total NA passé de 38 211 à 38 223).

# 4.21. Détecter les délais exceptionnellement élevés

Q1 <- quantile(df$processing_days, 0.25, na.rm = TRUE)
Q3 <- quantile(df$processing_days, 0.75, na.rm = TRUE)
ecart_interquartile <- IQR(df$processing_days, na.rm = TRUE)

borne_inferieure <- Q1 - 1.5 * ecart_interquartile
borne_superieure <- Q3 + 1.5 * ecart_interquartile

borne_inferieure
borne_superieure

# Seuil statistique supérieur (méthode IQR) : 38 jours (borne inf. théorique à -10).


# 4.22. Identifier les délais supérieurs à la borne supérieure

df |>
  filter(processing_days > borne_superieure) |>
  summarise(
    nombre_observations = n(),
    demandes_distinctes = n_distinct(application_id),
    delai_minimum = min(processing_days),
    delai_maximum = max(processing_days)
  )

# 1 594 observations extrêmes (464 demandes distinctes, de 39 à 165 jours) : conservées car peuvent être réelles.


# 4.23. Répartition des délais extrêmes selon la décision


df |>
  filter(processing_days > borne_superieure) |>
  count(admission_decision, sort = TRUE)

# Répartition brute : 68,4 % admis (1 090), 23,7 % rejetés (378), 7,9 % liste d'attente (126).
# À relativiser selon le volume total de chaque catégorie.


# 4.24. Répartition des délais extrêmes selon le programme

df |>
  filter(processing_days > borne_superieure) |>
  count(program, sort = TRUE)

# Volumes bruts les plus élevés : Computer Programming (236), Business Administration (211), Office Administration (202).


# 4.25. Comparer les proportions de délais extrêmes par programme

proportions_extremes_programme <- df |>
  filter(!is.na(program), !is.na(processing_days)) |>
  group_by(program) |>
  summarise(
    nombre_observations = n(),
    nombre_delais_extremes = sum(processing_days > borne_superieure),
    proportion_extremes = round(
      mean(processing_days > borne_superieure) * 100,
      2
    ),
    .groups = "drop"
  ) |>
  arrange(desc(proportion_extremes))

proportions_extremes_programme

# Taux variant de 2,34 % (Hospitality Management) à 4,21 % (Office Administration).
# Test statistique requis pour valider la significativité des écarts.


# 4.26. Répartition des délais extrêmes selon les extractions

delais_extremes_hebdo <- df |>
  filter(processing_days > borne_superieure) |>
  count(weekly_snapshot, name = "nombre_delais_extremes") |>
  arrange(weekly_snapshot)

delais_extremes_hebdo

# Suivi hebdomadaire des délais extrêmes (ne pas cumuler les périodes : un même retard peut persister d'une extraction à l'autre).


# 5. CONSTITUER UN FICHIER AVEC LA DERNIÈRE OBSERVATION PAR DEMANDE --------

# 5.1. Vérifier l'unicité demande / date d'extraction

doublons_demande_snapshot <- df |>
  count(application_id, weekly_snapshot) |>
  filter(n > 1)

nrow(doublons_demande_snapshot)

# Contrôle d'unicité par semaine avant extraction de l'état final.

if (nrow(doublons_demande_snapshot) > 0) {
  stop("Des doublons application_id / weekly_snapshot doivent être examinés.")
}


# 5.2. Créer le tableau des dernières observations

df_final <- df |>
  arrange(application_id, weekly_snapshot) |>
  group_by(application_id) |>
  slice_tail(n = 1) |>
  ungroup()

dim(df_final)
n_distinct(df_final$application_id)
sum(duplicated(df_final$application_id))

# df : historique hebdomadaire complet.
# df_final : dernière photo connue par demande (1 ligne = 1 demande unique).


# 5.3. Vérifier la date de la dernière extraction

max(df_final$weekly_snapshot)
nrow(df_final)

# Confirmation de la date maximale de suivi et du nombre total de demandes uniques.


# 6. ANALYSES DESCRIPTIVES DES DEMANDES -----------------------------------

# 6.1. Répartition des demandes selon le statut

table_statuts <- df_final |>
  count(application_status, sort = TRUE)

table_statuts

# Volume de demandes distinctes par statut final observé.


# 6.2. Répartition des demandes selon la décision d'admission

table_decisions <- df_final |>
  count(admission_decision, sort = TRUE)

table_decisions

# Distribution des décisions finales (dossiers en attente inclus).


# 6.3. Répartition des demandes selon le programme

table_programmes <- df_final |>
  mutate(program_analyse = coalesce(program, "Non renseigné")) |>
  count(program_analyse, sort = TRUE)

table_programmes

# Volume par programme (regroupement des NA sous "Non renseigné" pour l'affichage).


# 6.4. Répartition selon le niveau d'études

table_niveaux <- df_final |>
  count(study_level, sort = TRUE)

table_niveaux

# Répartition des demandes uniques par niveau d'études.


# 6.5. Répartition selon le canal de candidature

table_canaux <- df_final |>
  mutate(canal_analyse = coalesce(application_channel, "Non renseigné")) |>
  count(canal_analyse, sort = TRUE)

table_canaux

# Volume par canal de soumission (regroupement temporaire des NA sous "Non renseigné").


# 7. ANALYSE DES INSCRIPTIONS ---------------------------------------------

# 7.1. Examiner les inscriptions selon la décision

table_inscriptions_decision <- df_final |>
  count(admission_decision, registration_status, sort = TRUE)

table_inscriptions_decision

# Croisement décision d'admission / statut d'inscription (inscrits, en attente, désistements).


# 7.2. Calculer le taux d'inscription parmi les demandes admises

admis <- df_final |>
  filter(admission_decision == "Admitted")

resume_inscriptions <- admis |>
  summarise(
    nombre_admis = n(),
    nombre_inscrits = sum(registration_status == "Registered", na.rm = TRUE),
    taux_inscription = round(
      nombre_inscrits / nombre_admis * 100,
      2
    )
  )

resume_inscriptions

# Taux de conversion observé (Registered / Admitted) à la dernière extraction (non définitif).


# 7.3. Décrire les statuts d'inscription parmi les admis

admis |>
  count(registration_status, sort = TRUE)

# Détail des suites données par les candidats admis.


# 8. ANALYSE DES DÉLAIS DE TRAITEMENT -------------------------------------

# 8.1. Statistiques descriptives des délais dans le dernier état

summary(df_final$processing_days)

quantile(
  df_final$processing_days,
  probs = c(0.25, 0.50, 0.75),
  na.rm = TRUE
)

IQR(df_final$processing_days, na.rm = TRUE)

# Indicateurs calculés sur les dossiers uniques (df_final), sans imputation des NA.


# 8.2. Délais selon la décision d'admission

delais_par_decision <- df_final |>
  filter(!is.na(processing_days)) |>
  group_by(admission_decision) |>
  summarise(
    nombre = n(),
    moyenne = round(mean(processing_days), 2),
    mediane = median(processing_days),
    minimum = min(processing_days),
    maximum = max(processing_days),
    .groups = "drop"
  )

delais_par_decision

# Comparaison descriptive par décision (privilégier la médiane face aux valeurs extrêmes ; pas de lien causal démontré).


# 8.3. Délais selon le programme

delais_par_programme <- df_final |>
  filter(!is.na(processing_days), !is.na(program)) |>
  group_by(program) |>
  summarise(
    nombre = n(),
    moyenne = round(mean(processing_days), 2),
    mediane = median(processing_days),
    ecart_type = round(sd(processing_days), 2),
    .groups = "drop"
  ) |>
  arrange(desc(mediane))

delais_par_programme

# Comparaison par programme en croisant effectifs et médianes.


# 9. ANALYSES STATISTIQUES ------------------------------------------------

# 9.1. Association entre le programme et la décision d'admission

donnees_khi2 <- df_final |>
  filter(!is.na(program), !is.na(admission_decision))

table_programme_decision <- table(
  donnees_khi2$program,
  donnees_khi2$admission_decision
)

table_programme_decision

test_khi2 <- chisq.test(table_programme_decision)

test_khi2

# Vérifier les effectifs théoriques
test_khi2$expected

# Calculer le V de Cramer (intensité de l'association)
n_khi2 <- sum(table_programme_decision)
dimensions_khi2 <- dim(table_programme_decision)

v_cramer <- sqrt(
  as.numeric(test_khi2$statistic) /
    (n_khi2 * min(dimensions_khi2 - 1))
)

v_cramer

# Test du Khi-deux + V de Cramer : mesure l'association statistique (sans causalité).
# Contrôler la validité des effectifs théoriques.


# 9.2. Comparer les délais moyens selon le programme : ANOVA

donnees_anova <- df_final |>
  filter(!is.na(processing_days), !is.na(program)) |>
  mutate(program = as.factor(program))

modele_anova <- aov(processing_days ~ program, data = donnees_anova)

summary(modele_anova)

# Diagnostic graphique des résidus
par(mfrow = c(2, 2))
plot(modele_anova)
par(mfrow = c(1, 1))

# Compare les moyennes entre programmes (vérifier normalité des résidus et homogénéité des variances).
# Note : sur grands échantillons, de faibles écarts peuvent être statistiquement significatifs.


# 10. VISUALISATIONS ------------------------------------------------------

# 10.1. Nombre de demandes par statut

graphique_statuts <- ggplot(
  table_statuts,
  aes(x = reorder(application_status, n), y = n)
) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Nombre de demandes par statut",
    x = "Statut de la demande",
    y = "Nombre de demandes"
  ) +
  theme_minimal()

print(graphique_statuts)


# 10.2. Nombre de demandes par programme

graphique_programmes <- ggplot(
  table_programmes,
  aes(x = reorder(program_analyse, n), y = n)
) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Nombre de demandes par programme",
    x = "Programme",
    y = "Nombre de demandes"
  ) +
  theme_minimal()

print(graphique_programmes)


# 10.3. Répartition des décisions d'admission

graphique_decisions <- ggplot(
  table_decisions,
  aes(x = admission_decision, y = n)
) +
  geom_col() +
  labs(
    title = "Répartition des décisions d'admission",
    x = "Décision d'admission",
    y = "Nombre de demandes"
  ) +
  theme_minimal()

print(graphique_decisions)


# 10.4. Distribution des délais de traitement

graphique_delais <- ggplot(
  df_final |> filter(!is.na(processing_days)),
  aes(x = processing_days)
) +
  geom_histogram(binwidth = 5, boundary = 0) +
  labs(
    title = "Distribution des délais de traitement",
    x = "Délai de traitement (jours)",
    y = "Nombre de demandes"
  ) +
  theme_minimal()

print(graphique_delais)


# 10.5. Comparaison des délais par programme

graphique_delais_programme <- ggplot(
  df_final |> filter(!is.na(processing_days), !is.na(program)),
  aes(x = reorder(program, processing_days, FUN = median),
      y = processing_days)
) +
  geom_boxplot() +
  coord_flip() +
  labs(
    title = "Délais de traitement selon le programme",
    x = "Programme",
    y = "Délai de traitement (jours)"
  ) +
  theme_minimal()

print(graphique_delais_programme)


# 10.6. Évolution hebdomadaire du volume de demandes observées

evolution_hebdomadaire <- df |>
  group_by(weekly_snapshot) |>
  summarise(
    demandes_distinctes = n_distinct(application_id),
    .groups = "drop"
  ) |>
  arrange(weekly_snapshot)

evolution_hebdomadaire

graphique_evolution <- ggplot(
  evolution_hebdomadaire,
  aes(x = weekly_snapshot, y = demandes_distinctes)
) +
  geom_line() +
  geom_point() +
  labs(
    title = "Évolution hebdomadaire des demandes observées",
    x = "Date de l'extraction",
    y = "Nombre de demandes distinctes observées"
  ) +
  theme_minimal()

print(graphique_evolution)

# Représente le stock cumulé de dossiers actifs par semaine (et non le flux de nouvelles candidatures).


# 11. EXPORTER LES RÉSULTATS ----------------------------------------------

# Créer le dossier de sortie si absent
if (!dir.exists("outputs")) {
  dir.create("outputs")
}

# Exporter les bases nettoyées (longitudinale et finale)
write.csv(
  df,
  "outputs/donnees_nettoyees_longitudinales.csv",
  row.names = FALSE,
  na = ""
)

write.csv(
  df_final,
  "outputs/derniere_observation_par_demande.csv",
  row.names = FALSE,
  na = ""
)

# Exporter les tableaux de synthèse
write.csv(
  table_statuts,
  "outputs/repartition_statuts.csv",
  row.names = FALSE
)

write.csv(
  table_decisions,
  "outputs/repartition_decisions.csv",
  row.names = FALSE
)

write.csv(
  table_programmes,
  "outputs/repartition_programmes.csv",
  row.names = FALSE
)

write.csv(
  resume_inscriptions,
  "outputs/taux_inscription_admis.csv",
  row.names = FALSE
)

write.csv(
  delais_par_decision,
  "outputs/delais_par_decision.csv",
  row.names = FALSE
)

write.csv(
  delais_par_programme,
  "outputs/delais_par_programme.csv",
  row.names = FALSE
)

write.csv(
  proportions_extremes_programme,
  "outputs/proportions_delais_extremes_programme.csv",
  row.names = FALSE
)

write.csv(
  evolution_hebdomadaire,
  "outputs/evolution_hebdomadaire.csv",
  row.names = FALSE
)

# Sauvegarder les graphiques
ggsave("outputs/graphique_statuts.png", graphique_statuts,
       width = 8, height = 5)

ggsave("outputs/graphique_programmes.png", graphique_programmes,
       width = 9, height = 6)

ggsave("outputs/graphique_decisions.png", graphique_decisions,
       width = 8, height = 5)

ggsave("outputs/graphique_delais.png", graphique_delais,
       width = 8, height = 5)

ggsave("outputs/graphique_delais_programme.png",
       graphique_delais_programme, width = 9, height = 6)

ggsave("outputs/graphique_evolution_hebdomadaire.png",
       graphique_evolution, width = 8, height = 5)

# L'ensemble des livrables (données, tableaux, graphiques) est enregistré dans outputs/.


# 12. BILAN DU PROJET -----------------------------------------------------

# - Nettoyage : Fusion de 12 extractions, standardisation des NA et des catégories, suppression de 80 doublons exacts.
# - Anomalies : 12 délais négatifs (-4 j) passés en NA ; délais extrêmes (>38 j) et incohérences de statuts documentés mais conservés.
# - Architecture : df pour le suivi longitudinal ; df_final pour l'état le plus récent sans doublons d'identifiants.
# - Limites : Données synthétiques (non généralisables) ; les tests statistiques montrent des associations, pas une causalité.