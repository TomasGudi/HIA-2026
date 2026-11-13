-- ============================================================
-- Campos personalizados de Mantis (§11)
--
-- Vinculan cada incidencia con el código que la corrigió, sin depender
-- de que el commit esté escrito en una nota.
--
-- Se aplica sobre la base `mantis`:
--   docker compose exec -T db psql -U practica_app -d mantis -f - < scripts/mantis-campos.sql
-- ============================================================

-- 1) definición de los campos
INSERT INTO mantis_custom_field_table (
  name, type, possible_values, default_value, valid_regexp,
  access_level_r, access_level_rw, length_min, length_max, filter_by,
  display_report, display_update, display_resolved, display_closed,
  require_report, require_update, require_resolved, require_closed
)
SELECT 'commit_sha', 0, '', '', '', 10, 10, 0, 40, false,
       false, true, true, true, false, false, false, false
WHERE NOT EXISTS (SELECT 1 FROM mantis_custom_field_table WHERE name = 'commit_sha');

INSERT INTO mantis_custom_field_table (
  name, type, possible_values, default_value, valid_regexp,
  access_level_r, access_level_rw, length_min, length_max, filter_by,
  display_report, display_update, display_resolved, display_closed,
  require_report, require_update, require_resolved, require_closed
)
SELECT 'pr_url', 0, '', '', '', 10, 10, 0, 200, false,
       false, true, true, true, false, false, false, false
WHERE NOT EXISTS (SELECT 1 FROM mantis_custom_field_table WHERE name = 'pr_url');

-- 2) asociarlos al proyecto HIA-2026
INSERT INTO mantis_custom_field_project_table (field_id, project_id, sequence)
SELECT f.id, p.id, CASE WHEN f.name = 'commit_sha' THEN 0 ELSE 1 END
FROM mantis_custom_field_table f
CROSS JOIN mantis_project_table p
WHERE f.name IN ('commit_sha', 'pr_url')
  AND p.name = 'HIA-2026'
  AND NOT EXISTS (
    SELECT 1 FROM mantis_custom_field_project_table x
    WHERE x.field_id = f.id AND x.project_id = p.id
  );

-- 3) valores por incidencia (el id coincide con el orden de scripts/mantis-seed.py)
WITH datos(bug_id, sha, pr) AS (
  VALUES
    (1,  '2d6f360', 'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (2,  '2d6f360', 'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (3,  '2d6f360', 'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (4,  '9b77ac0', 'https://github.com/TomasGudi/HIA-2026/pull/9'),
    (5,  'e08768f', 'https://github.com/TomasGudi/HIA-2026/pull/4'),
    (6,  'e08768f', 'https://github.com/TomasGudi/HIA-2026/pull/4'),
    (7,  '2d6f360', 'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (8,  '8bf8625', 'https://github.com/TomasGudi/HIA-2026/pull/3'),
    (9,  '2d6f360', 'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (10, '2d6f360', 'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (11, '2d6f360', 'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (12, '7a4c271', 'https://github.com/TomasGudi/HIA-2026/pull/8'),
    (13, '88cfb9c', 'https://github.com/TomasGudi/HIA-2026/pull/5'),
    (14, '7a4c271', 'https://github.com/TomasGudi/HIA-2026/pull/8')
)
INSERT INTO mantis_custom_field_string_table (field_id, bug_id, value)
SELECT (SELECT id FROM mantis_custom_field_table WHERE name = 'commit_sha'), d.bug_id, d.sha
FROM datos d
JOIN mantis_bug_table b ON b.id = d.bug_id
WHERE NOT EXISTS (
  SELECT 1 FROM mantis_custom_field_string_table s
  WHERE s.field_id = (SELECT id FROM mantis_custom_field_table WHERE name = 'commit_sha')
    AND s.bug_id = d.bug_id
);

WITH datos(bug_id, pr) AS (
  VALUES
    (1,  'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (2,  'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (3,  'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (4,  'https://github.com/TomasGudi/HIA-2026/pull/9'),
    (5,  'https://github.com/TomasGudi/HIA-2026/pull/4'),
    (6,  'https://github.com/TomasGudi/HIA-2026/pull/4'),
    (7,  'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (8,  'https://github.com/TomasGudi/HIA-2026/pull/3'),
    (9,  'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (10, 'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (11, 'https://github.com/TomasGudi/HIA-2026/pull/2'),
    (12, 'https://github.com/TomasGudi/HIA-2026/pull/8'),
    (13, 'https://github.com/TomasGudi/HIA-2026/pull/5'),
    (14, 'https://github.com/TomasGudi/HIA-2026/pull/8')
)
INSERT INTO mantis_custom_field_string_table (field_id, bug_id, value)
SELECT (SELECT id FROM mantis_custom_field_table WHERE name = 'pr_url'), d.bug_id, d.pr
FROM datos d
JOIN mantis_bug_table b ON b.id = d.bug_id
WHERE NOT EXISTS (
  SELECT 1 FROM mantis_custom_field_string_table s
  WHERE s.field_id = (SELECT id FROM mantis_custom_field_table WHERE name = 'pr_url')
    AND s.bug_id = d.bug_id
);
