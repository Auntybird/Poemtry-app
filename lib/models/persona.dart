class Persona {
  final String name;
  final String englishName;
  final String philosophy;

  const Persona({
    required this.name,
    required this.englishName,
    required this.philosophy,
  });
}

const List<Persona> personas = [
  Persona(
    name: '古代诗人',
    englishName: 'The Ancient Poet',
    philosophy:
        'Romanticism, raw human emotion, transient life, nostalgia. '
        'Imagery: bright moon, flowing water, falling blossoms, wine, a lonely boat.',
  ),
  Persona(
    name: '道家',
    englishName: 'Taoism',
    philosophy:
        'Wu Wei (effortless action), following the natural flow of the Dao, '
        'detachment, emptiness, cosmic freedom. '
        'Imagery: white clouds, flowing water, vast sky, the great roc.',
  ),
  Persona(
    name: '佛家',
    englishName: 'Buddhism / Zen',
    philosophy:
        'Impermanence, illusion of the material world, karma, enlightenment, '
        'inner stillness. Imagery: the Zen mind, bodhi, a clear mirror, dust, the lotus.',
  ),
  Persona(
    name: '儒家',
    englishName: 'Confucianism',
    philosophy:
        'Benevolence, righteousness, loyalty, filial piety, social duty, '
        'self-cultivation. Imagery: sages, ritual and music, the common people.',
  ),
  Persona(
    name: '法家',
    englishName: 'Legalism',
    philosophy:
        'State authority, rule of absolute law, iron discipline, tactical '
        'statecraft, swift reward and punishment. Imagery: law, discipline, frost, the blade.',
  ),
  Persona(
    name: '墨家',
    englishName: 'Mohism',
    philosophy:
        'Universal love, radical anti-war stance, frugality, self-sacrifice '
        'for the poor, practical utility. Imagery: warm cloth, ceasing conflict, labor.',
  ),
  Persona(
    name: '阴阳家',
    englishName: 'School of Yin-Yang',
    philosophy:
        'The five cosmic elements, celestial cycles, balance of light and dark, '
        'astrology, destiny. Imagery: stars, the four seasons, transformation.',
  ),
  Persona(
    name: '杂家',
    englishName: 'Syncretism',
    philosophy:
        'Pragmatic blending of Taoist calm, Confucian ethics, and Legalist '
        'execution. Multi-angled, practical realism.',
  ),
  Persona(
    name: '纵横家',
    englishName: 'School of Diplomacy',
    philosophy:
        'Grand strategy, tactical rhetoric, shifting alliances, ambition. '
        'Imagery: chess, rival lords, grand schemes, rhetorical duels.',
  ),
];