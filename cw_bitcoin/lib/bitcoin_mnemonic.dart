import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'package:cryptography/cryptography.dart' as cryptography;
import 'package:cake_wallet/core/sec_random_native.dart';

const segwit = '100';
final wordlist = englishWordlist;

double logBase(num x, num base) => log(x) / log(base);

String mnemonicEncode(int i) {
  var _i = i;
  final n = wordlist.length;
  final words = <String>[];

  while (_i > 0) {
    final x = i % n;
    _i = (i / n).floor();
    words.add(wordlist[x]);
  }

  return words.join(' ');
}

int mnemonicDecode(String seed) {
  var i = 0;
  final n = wordlist.length;
  final words = seed.split(' ');

  while (words.length > 0) {
    final word = words.removeLast();
    final k = wordlist.indexOf(word);
    i = i * n + k;
  }

  return i;
}

bool isNewSeed(String seed, {String prefix = segwit}) {
  final hmacSha512 = Hmac(sha512, utf8.encode('Seed version'));
  final digest = hmacSha512.convert(utf8.encode(normalizeText(seed)));
  final hx = digest.toString();
  return hx.startsWith(prefix.toLowerCase());
}

void maskBytes(Uint8List bytes, int bits) {
  final skipCount = (bits / 8).floor();
  var lastByte = (1 << bits % 8) - 1;

  for (var i = bytes.length - 1 - skipCount; i >= 0; i--) {
    bytes[i] &= lastByte;

    if (lastByte > 0) {
      lastByte = 0;
    }
  }
}

String bufferToBin(Uint8List data) {
  final q1 = data.map((e) => e.toRadixString(2).padLeft(8, '0'));
  final q2 = q1.join('');
  return q2;
}

String encode(Uint8List data) {
  final dataBitLen = data.length * 8;
  final wordBitLen = logBase(wordlist.length, 2).ceil();
  final wordCount = (dataBitLen / wordBitLen).floor();
  maskBytes(data, wordCount * wordBitLen);
  final bin = bufferToBin(data);
  final binStr = bin.substring(bin.length - (wordCount * wordBitLen));
  final result = <Object>[];

  for (var i = 0; i < wordCount; i++) {
    final wordBin = binStr.substring(i * wordBitLen, (i + 1) * wordBitLen);
    result.add(wordlist[int.parse(wordBin, radix: 2)]);
  }

  return result.join(' ');
}

List<bool> prefixMatches(String source, List<String> prefixes) {
  final hmacSha512 = Hmac(sha512, utf8.encode('Seed version'));
  final digest = hmacSha512.convert(utf8.encode(normalizeText(source)));
  final hx = digest.toString();

  return prefixes.map((prefix) => hx.startsWith(prefix.toLowerCase())).toList();
}

Future<String> generateMnemonic(
    {int strength = 264, String prefix = segwit}) async {
  final wordBitlen = logBase(wordlist.length, 2).ceil();
  final wordCount = strength / wordBitlen;
  final byteCount = ((wordCount * wordBitlen).ceil() / 8).ceil();
  var result = '';

  do {
    final bytes = await secRandom(byteCount);
    maskBytes(bytes, strength);
    result = encode(bytes);
  } while (!prefixMatches(result, [prefix]).first);

  return result;
}

Uint8List mnemonicToSeedBytes(String mnemonic, {String prefix = segwit}) {
  final pbkdf2 = cryptography.Pbkdf2(
      macAlgorithm: cryptography.Hmac(cryptography.sha512),
      iterations: 2048,
      bits: 512);
  final text = normalizeText(mnemonic);

  return pbkdf2.deriveBitsSync(text.codeUnits,
      nonce: cryptography.Nonce('electrum'.codeUnits));
}

bool matchesAnyPrefix(String mnemonic) =>
    prefixMatches(mnemonic, [segwit]).any((el) => el);

bool validateMnemonic(String mnemonic, {String prefix = segwit}) {
  try {
    return matchesAnyPrefix(mnemonic);
  } catch (e) {
    return false;
  }
}

final COMBININGCODEPOINTS = combiningcodepoints();

List<int> combiningcodepoints() {
  final source = '300:34e|350:36f|483:487|591:5bd|5bf|5c1|5c2|5c4|5c5|5c7|610:61a|64b:65f|670|' +
      '6d6:6dc|6df:6e4|6e7|6e8|6ea:6ed|711|730:74a|7eb:7f3|816:819|81b:823|825:827|' +
      '829:82d|859:85b|8d4:8e1|8e3:8ff|93c|94d|951:954|9bc|9cd|a3c|a4d|abc|acd|b3c|' +
      'b4d|bcd|c4d|c55|c56|cbc|ccd|d4d|dca|e38:e3a|e48:e4b|eb8|eb9|ec8:ecb|f18|f19|' +
      'f35|f37|f39|f71|f72|f74|f7a:f7d|f80|f82:f84|f86|f87|fc6|1037|1039|103a|108d|' +
      '135d:135f|1714|1734|17d2|17dd|18a9|1939:193b|1a17|1a18|1a60|1a75:1a7c|1a7f|' +
      '1ab0:1abd|1b34|1b44|1b6b:1b73|1baa|1bab|1be6|1bf2|1bf3|1c37|1cd0:1cd2|' +
      '1cd4:1ce0|1ce2:1ce8|1ced|1cf4|1cf8|1cf9|1dc0:1df5|1dfb:1dff|20d0:20dc|20e1|' +
      '20e5:20f0|2cef:2cf1|2d7f|2de0:2dff|302a:302f|3099|309a|a66f|a674:a67d|a69e|' +
      'a69f|a6f0|a6f1|a806|a8c4|a8e0:a8f1|a92b:a92d|a953|a9b3|a9c0|aab0|aab2:aab4|' +
      'aab7|aab8|aabe|aabf|aac1|aaf6|abed|fb1e|fe20:fe2f|101fd|102e0|10376:1037a|' +
      '10a0d|10a0f|10a38:10a3a|10a3f|10ae5|10ae6|11046|1107f|110b9|110ba|11100:11102|' +
      '11133|11134|11173|111c0|111ca|11235|11236|112e9|112ea|1133c|1134d|11366:1136c|' +
      '11370:11374|11442|11446|114c2|114c3|115bf|115c0|1163f|116b6|116b7|1172b|11c3f|' +
      '16af0:16af4|16b30:16b36|1bc9e|1d165:1d169|1d16d:1d172|1d17b:1d182|1d185:1d18b|' +
      '1d1aa:1d1ad|1d242:1d244|1e000:1e006|1e008:1e018|1e01b:1e021|1e023|1e024|' +
      '1e026:1e02a|1e8d0:1e8d6|1e944:1e94a';

  return source.split('|').map((e) {
    if (e.contains(':')) {
      return e.split(':').map((hex) => int.parse(hex, radix: 16));
    }

    return int.parse(e, radix: 16);
  }).fold(<int>[], (List<int> acc, element) {
    if (element is List) {
      for (var i = element[0] as int; i <= (element[1] as int); i++) {}
    } else if (element is int) {
      acc.add(element);
    }

    return acc;
  }).toList();
}

String removeCombiningCharacters(String source) {
  return source
      .split('')
      .where((char) => !COMBININGCODEPOINTS.contains(char.codeUnits.first))
      .join('');
}

bool isCJK(String char) {
  final n = char.codeUnitAt(0);

  for (var x in CJKINTERVALS) {
    final imin = x[0] as num;
    final imax = x[1] as num;

    if (n >= imin && n <= imax) return true;
  }

  return false;
}

String removeCJKSpaces(String source) {
  final splitted = source.split('');
  final filtered = <String>[];

  for (var i = 0; i < splitted.length; i++) {
    final char = splitted[i];
    final isSpace = char.trim() == '';
    final prevIsCJK = i != 0 && isCJK(splitted[i - 1]);
    final nextIsCJK = i != splitted.length - 1 && isCJK(splitted[i + 1]);

    if (!(isSpace && prevIsCJK && nextIsCJK)) {
      filtered.add(char);
    }
  }

  return filtered.join('');
}

String normalizeText(String source) {
  final res = removeCombiningCharacters(unorm.nfkd(source).toLowerCase())
      .trim()
      .split('/\s+/')
      .join(' ');

  return removeCJKSpaces(res);
}

const CJKINTERVALS = [
  [0x4e00, 0x9fff, 'CJK Unified Ideographs'],
  [0x3400, 0x4dbf, 'CJK Unified Ideographs Extension A'],
  [0x20000, 0x2a6df, 'CJK Unified Ideographs Extension B'],
  [0x2a700, 0x2b73f, 'CJK Unified Ideographs Extension C'],
  [0x2b740, 0x2b81f, 'CJK Unified Ideographs Extension D'],
  [0xf900, 0xfaff, 'CJK Compatibility Ideographs'],
  [0x2f800, 0x2fa1d, 'CJK Compatibility Ideographs Supplement'],
  [0x3190, 0x319f, 'Kanbun'],
  [0x2e80, 0x2eff, 'CJK Radicals Supplement'],
  [0x2f00, 0x2fdf, 'CJK Radicals'],
  [0x31c0, 0x31ef, 'CJK Strokes'],
  [0x2ff0, 0x2fff, 'Ideographic Description Characters'],
  [0xe0100, 0xe01ef, 'Variation Selectors Supplement'],
  [0x3100, 0x312f, 'Bopomofo'],
  [0x31a0, 0x31bf, 'Bopomofo Extended'],
  [0xff00, 0xffef, 'Halfwidth and Fullwidth Forms'],
  [0x3040, 0x309f, 'Hiragana'],
  [0x30a0, 0x30ff, 'Katakana'],
  [0x31f0, 0x31ff, 'Katakana Phonetic Extensions'],
  [0x1b000, 0x1b0ff, 'Kana Supplement'],
  [0xac00, 0xd7af, 'Hangul Syllables'],
  [0x1100, 0x11ff, 'Hangul Jamo'],
  [0xa960, 0xa97f, 'Hangul Jamo Extended A'],
  [0xd7b0, 0xd7ff, 'Hangul Jamo Extended B'],
  [0x3130, 0x318f, 'Hangul Compatibility Jamo'],
  [0xa4d0, 0xa4ff, 'Lisu'],
  [0x16f00, 0x16f9f, 'Miao'],
  [0xa000, 0xa48f, 'Yi Syllables'],
  [0xa490, 0xa4cf, 'Yi Radicals'],
];

final englishWordlist = <String>[
  'abandon',
  'ability',
  'able',
  'about',
  'above',
  'absent',
  'absorb',
  'abstract',
  'absurd',
  'abuse',
  'access',
  'accident',
  'account',
  'accuse',
  'achieve',
  'acid',
  'acoustic',
  'acquire',
  'across',
  'act',
  'action',
  'actor',
  'actress',
  'actual',
  'adapt',
  'add',
  'addict',
  'address',
  'adjust',
  'admit',
  'adult',
  'advance',
  'advice',
  'aerobic',
  'affair',
  'afford',
  'afraid',
  'again',
  'age',
  'agent',
  'agree',
  'ahead',
  'aim',
  'air',
  'airport',
  'aisle',
  'alarm',
  'album',
  'alcohol',
  'alert',
  'alien',
  'all',
  'alley',
  'allow',
  'almost',
  'alone',
  'alpha',
  'already',
  'also',
  'alter',
  'always',
  'amateur',
  'amazing',
  'among',
  'amount',
  'amused',
  'analyst',
  'anchor',
  'ancient',
  'anger',
  'angle',
  'angry',
  'animal',
  'ankle',
  'announce',
  'annual',
  'another',
  'answer',
  'antenna',
  'antique',
  'anxiety',
  'any',
  'apart',
  'apology',
  'appear',
  'apple',
  'approve',
  'april',
  'arch',
  'arctic',
  'area',
  'arena',
  'argue',
  'arm',
  'armed',
  'armor',
  'army',
  'around',
  'arrange',
  'arrest',
  'arrive',
  'arrow',
  'art',
  'artefact',
  'artist',
  'artwork',
  'ask',
  'aspect',
  'assault',
  'asset',
  'assist',
  'assume',
  'asthma',
  'athlete',
  'atom',
  'attack',
  'attend',
  'attitude',
  'attract',
  'auction',
  'audit',
  'august',
  'aunt',
  'author',
  'auto',
  'autumn',
  'average',
  'avocado',
  'avoid',
  'awake',
  'aware',
  'away',
  'awesome',
  'awful',
  'awkward',
  'axis',
  'baby',
  'bachelor',
  'bacon',
  'badge',
  'bag',
  'balance',
  'balcony',
  'ball',
  'bamboo',
  'banana',
  'banner',
  'bar',
  'barely',
  'bargain',
  'barrel',
  'base',
  'basic',
  'basket',
  'battle',
  'beach',
  'bean',
  'beauty',
  'because',
  'become',
  'beef',
  'before',
  'begin',
  'behave',
  'behind',
  'believe',
  'below',
  'belt',
  'bench',
  'benefit',
  'best',
  'betray',
  'better',
  'between',
  'beyond',
  'bicycle',
  'bid',
  'bike',
  'bind',
  'biology',
  'bird',
  'birth',
  'bitter',
  'black',
  'blade',
  'blame',
  'blanket',
  'blast',
  'bleak',
  'bless',
  'blind',
  'blood',
  'blossom',
  'blouse',
  'blue',
  'blur',
  'blush',
  'board',
  'boat',
  'body',
  'boil',
  'bomb',
  'bone',
  'bonus',
  'book',
  'boost',
  'border',
  'boring',
  'borrow',
  'boss',
  'bottom',
  'bounce',
  'box',
  'boy',
  'bracket',
  'brain',
  'brand',
  'brass',
  'brave',
  'bread',
  'breeze',
  'brick',
  'bridge',
  'brief',
  'bright',
  'bring',
  'brisk',
  'broccoli',
  'broken',
  'bronze',
  'broom',
  'brother',
  'brown',
  'brush',
  'bubble',
  'buddy',
  'budget',
  'buffalo',
  'build',
  'bulb',
  'bulk',
  'bullet',
  'bundle',
  'bunker',
  'burden',
  'burger',
  'burst',
  'bus',
  'business',
  'busy',
  'butter',
  'buyer',
  'buzz',
  'cabbage',
  'cabin',
  'cable',
  'cactus',
  'cage',
  'cake',
  'call',
  'calm',
  'camera',
  'camp',
  'can',
  'canal',
  'cancel',
  'candy',
  'cannon',
  'canoe',
  'canvas',
  'canyon',
  'capable',
  'capital',
  'captain',
  'car',
  'carbon',
  'card',
  'cargo',
  'carpet',
  'carry',
  'cart',
  'case',
  'cash',
  'casino',
  'castle',
  'casual',
  'cat',
  'catalog',
  'catch',
  'category',
  'cattle',
  'caught',
  'cause',
  'caution',
  'cave',
  'ceiling',
  'celery',
  'cement',
  'census',
  'century',
  'cereal',
  'certain',
  'chair',
  'chalk',
  'champion',
  'change',
  'chaos',
  'chapter',
  'charge',
  'chase',
  'chat',
  'cheap',
  'check',
  'cheese',
  'chef',
  'cherry',
  'chest',
  'chicken',
  'chief',
  'child',
  'chimney',
  'choice',
  'choose',
  'chronic',
  'chuckle',
  'chunk',
  'churn',
  'cigar',
  'cinnamon',
  'circle',
  'citizen',
  'city',
  'civil',
  'claim',
  'clap',
  'clarify',
  'claw',
  'clay',
  'clean',
  'clerk',
  'clever',
  'click',
  'client',
  'cliff',
  'climb',
  'clinic',
  'clip',
  'clock',
  'clog',
  'close',
  'cloth',
  'cloud',
  'clown',
  'club',
  'clump',
  'cluster',
  'clutch',
  'coach',
  'coast',
  'coconut',
  'code',
  'coffee',
  'coil',
  'coin',
  'collect',
  'color',
  'column',
  'combine',
  'come',
  'comfort',
  'comic',
  'common',
  'company',
  'concert',
  'conduct',
  'confirm',
  'congress',
  'connect',
  'consider',
  'control',
  'convince',
  'cook',
  'cool',
  'copper',
  'copy',
  'coral',
  'core',
  'corn',
  'correct',
  'cost',
  'cotton',
  'couch',
  'country',
  'couple',
  'course',
  'cousin',
  'cover',
  'coyote',
  'crack',
  'cradle',
  'craft',
  'cram',
  'crane',
  'crash',
  'crater',
  'crawl',
  'crazy',
  'cream',
  'credit',
  'creek',
  'crew',
  'cricket',
  'crime',
  'crisp',
  'critic',
  'crop',
  'cross',
  'crouch',
  'crowd',
  'crucial',
  'cruel',
  'cruise',
  'crumble',
  'crunch',
  'crush',
  'cry',
  'crystal',
  'cube',
  'culture',
  'cup',
  'cupboard',
  'curious',
  'current',
  'curtain',
  'curve',
  'cushion',
  'custom',
  'cute',
  'cycle',
  'dad',
  'damage',
  'damp',
  'dance',
  'danger',
  'daring',
  'dash',
  'daughter',
  'dawn',
  'day',
  'deal',
  'debate',
  'debris',
  'decade',
  'december',
  'decide',
  'decline',
  'decorate',
  'decrease',
  'deer',
  'defense',
  'define',
  'defy',
  'degree',
  'delay',
  'deliver',
  'demand',
  'demise',
  'denial',
  'dentist',
  'deny',
  'depart',
  'depend',
  'deposit',
  'depth',
  'deputy',
  'derive',
  'describe',
  'desert',
  'design',
  'desk',
  'despair',
  'destroy',
  'detail',
  'detect',
  'develop',
  'device',
  'devote',
  'diagram',
  'dial',
  'diamond',
  'diary',
  'dice',
  'diesel',
  'diet',
  'differ',
  'digital',
  'dignity',
  'dilemma',
  'dinner',
  'dinosaur',
  'direct',
  'dirt',
  'disagree',
  'discover',
  'disease',
  'dish',
  'dismiss',
  'disorder',
  'display',
  'distance',
  'divert',
  'divide',
  'divorce',
  'dizzy',
  'doctor',
  'document',
  'dog',
  'doll',
  'dolphin',
  'domain',
  'donate',
  'donkey',
  'donor',
  'door',
  'dose',
  'double',
  'dove',
  'draft',
  'dragon',
  'drama',
  'drastic',
  'draw',
  'dream',
  'dress',
  'drift',
  'drill',
  'drink',
  'drip',
  'drive',
  'drop',
  'drum',
  'dry',
  'duck',
  'dumb',
  'dune',
  'during',
  'dust',
  'dutch',
  'duty',
  'dwarf',
  'dynamic',
  'eager',
  'eagle',
  'early',
  'earn',
  'earth',
  'easily',
  'east',
  'easy',
  'echo',
  'ecology',
  'economy',
  'edge',
  'edit',
  'educate',
  'effort',
  'egg',
  'eight',
  'either',
  'elbow',
  'elder',
  'electric',
  'elegant',
  'element',
  'elephant',
  'elevator',
  'elite',
  'else',
  'embark',
  'embody',
  'embrace',
  'emerge',
  'emotion',
  'employ',
  'empower',
  'empty',
  'enable',
  'enact',
  'end',
  'endless',
  'endorse',
  'enemy',
  'energy',
  'enforce',
  'engage',
  'engine',
  'enhance',
  'enjoy',
  'enlist',
  'enough',
  'enrich',
  'enroll',
  'ensure',
  'enter',
  'entire',
  'entry',
  'envelope',
  'episode',
  'equal',
  'equip',
  'era',
  'erase',
  'erode',
  'erosion',
  'error',
  'erupt',
  'escape',
  'essay',
  'essence',
  'estate',
  'eternal',
  'ethics',
  'evidence',
  'evil',
  'evoke',
  'evolve',
  'exact',
  'example',
  'excess',
  'exchange',
  'excite',
  'exclude',
  'excuse',
  'execute',
  'exercise',
  'exhaust',
  'exhibit',
  'exile',
  'exist',
  'exit',
  'exotic',
  'expand',
  'expect',
  'expire',
  'explain',
  'expose',
  'express',
  'extend',
  'extra',
  'eye',
  'eyebrow',
  'fabric',
  'face',
  'faculty',
  'fade',
  'faint',
  'faith',
  'fall',
  'false',
  'fame',
  'family',
  'famous',
  'fan',
  'fancy',
  'fantasy',
  'farm',
  'fashion',
  'fat',
  'fatal',
  'father',
  'fatigue',
  'fault',
  'favorite',
  'feature',
  'february',
  'federal',
  'fee',
  'feed',
  'feel',
  'female',
  'fence',
  'festival',
  'fetch',
  'fever',
  'few',
  'fiber',
  'fiction',
  'field',
  'figure',
  'file',
  'film',
  'filter',
  'final',
  'find',
  'fine',
  'finger',
  'finish',
  'fire',
  'firm',
  'first',
  'fiscal',
  'fish',
  'fit',
  'fitness',
  'fix',
  'flag',
  'flame',
  'flash',
  'flat',
  'flavor',
  'flee',
  'flight',
  'flip',
  'float',
  'flock',
  'floor',
  'flower',
  'fluid',
  'flush',
  'fly',
  'foam',
  'focus',
  'fog',
  'foil',
  'fold',
  'follow',
  'food',
  'foot',
  'force',
  'forest',
  'forget',
  'fork',
  'fortune',
  'forum',
  'forward',
  'fossil',
  'foster',
  'found',
  'fox',
  'fragile',
  'frame',
  'frequent',
  'fresh',
  'friend',
  'fringe',
  'frog',
  'front',
  'frost',
  'frown',
  'frozen',
  'fruit',
  'fuel',
  'fun',
  'funny',
  'furnace',
  'fury',
  'future',
  'gadget',
  'gain',
  'galaxy',
  'gallery',
  'game',
  'gap',
  'garage',
  'garbage',
  'garden',
  'garlic',
  'garment',
  'gas',
  'gasp',
  'gate',
  'gather',
  'gauge',
  'gaze',
  'general',
  'genius',
  'genre',
  'gentle',
  'genuine',
  'gesture',
  'ghost',
  'giant',
  'gift',
  'giggle',
  'ginger',
  'giraffe',
  'girl',
  'give',
  'glad',
  'glance',
  'glare',
  'glass',
  'glide',
  'glimpse',
  'globe',
  'gloom',
  'glory',
  'glove',
  'glow',
  'glue',
  'goat',
  'goddess',
  'gold',
  'good',
  'goose',
  'gorilla',
  'gospel',
  'gossip',
  'govern',
  'gown',
  'grab',
  'grace',
  'grain',
  'grant',
  'grape',
  'grass',
  'gravity',
  'great',
  'green',
  'grid',
  'grief',
  'grit',
  'grocery',
  'group',
  'grow',
  'grunt',
  'guard',
  'guess',
  'guide',
  'guilt',
  'guitar',
  'gun',
  'gym',
  'habit',
  'hair',
  'half',
  'hammer',
  'hamster',
  'hand',
  'happy',
  'harbor',
  'hard',
  'harsh',
  'harvest',
  'hat',
  'have',
  'hawk',
  'hazard',
  'head',
  'health',
  'heart',
  'heavy',
  'hedgehog',
  'height',
  'hello',
  'helmet',
  'help',
  'hen',
  'hero',
  'hidden',
  'high',
  'hill',
  'hint',
  'hip',
  'hire',
  'history',
  'hobby',
  'hockey',
  'hold',
  'hole',
  'holiday',
  'hollow',
  'home',
  'honey',
  'hood',
  'hope',
  'horn',
  'horror',
  'horse',
  'hospital',
  'host',
  'hotel',
  'hour',
  'hover',
  'hub',
  'huge',
  'human',
  'humble',
  'humor',
  'hundred',
  'hungry',
  'hunt',
  'hurdle',
  'hurry',
  'hurt',
  'husband',
  'hybrid',
  'ice',
  'icon',
  'idea',
  'identify',
  'idle',
  'ignore',
  'ill',
  'illegal',
  'illness',
  'image',
  'imitate',
  'immense',
  'immune',
  'impact',
  'impose',
  'improve',
  'impulse',
  'inch',
  'include',
  'income',
  'increase',
  'index',
  'indicate',
  'indoor',
  'industry',
  'infant',
  'inflict',
  'inform',
  'inhale',
  'inherit',
  'initial',
  'inject',
  'injury',
  'inmate',
  'inner',
  'innocent',
  'input',
  'inquiry',
  'insane',
  'insect',
  'inside',
  'inspire',
  'install',
  'intact',
  'interest',
  'into',
  'invest',
  'invite',
  'involve',
  'iron',
  'island',
  'isolate',
  'issue',
  'item',
  'ivory',
  'jacket',
  'jaguar',
  'jar',
  'jazz',
  'jealous',
  'jeans',
  'jelly',
  'jewel',
  'job',
  'join',
  'joke',
  'journey',
  'joy',
  'judge',
  'juice',
  'jump',
  'jungle',
  'junior',
  'junk',
  'just',
  'kangaroo',
  'keen',
  'keep',
  'ketchup',
  'key',
  'kick',
  'kid',
  'kidney',
  'kind',
  'kingdom',
  'kiss',
  'kit',
  'kitchen',
  'kite',
  'kitten',
  'kiwi',
  'knee',
  'knife',
  'knock',
  'know',
  'lab',
  'label',
  'labor',
  'ladder',
  'lady',
  'lake',
  'lamp',
  'language',
  'laptop',
  'large',
  'later',
  'latin',
  'laugh',
  'laundry',
  'lava',
  'law',
  'lawn',
  'lawsuit',
  'layer',
  'lazy',
  'leader',
  'leaf',
  'learn',
  'leave',
  'lecture',
  'left',
  'leg',
  'legal',
  'legend',
  'leisure',
  'lemon',
  'lend',
  'length',
  'lens',
  'leopard',
  'lesson',
  'letter',
  'level',
  'liar',
  'liberty',
  'library',
  'license',
  'life',
  'lift',
  'light',
  'like',
  'limb',
  'limit',
  'link',
  'lion',
  'liquid',
  'list',
  'little',
  'live',
  'lizard',
  'load',
  'loan',
  'lobster',
  'local',
  'lock',
  'logic',
  'lonely',
  'long',
  'loop',
  'lottery',
  'loud',
  'lounge',
  'love',
  'loyal',
  'lucky',
  'luggage',
  'lumber',
  'lunar',
  'lunch',
  'luxury',
  'lyrics',
  'machine',
  'mad',
  'magic',
  'magnet',
  'maid',
  'mail',
  'main',
  'major',
  'make',
  'mammal',
  'man',
  'manage',
  'mandate',
  'mango',
  'mansion',
  'manual',
  'maple',
  'marble',
  'march',
  'margin',
  'marine',
  'market',
  'marriage',
  'mask',
  'mass',
  'master',
  'match',
  'material',
  'math',
  'matrix',
  'matter',
  'maximum',
  'maze',
  'meadow',
  'mean',
  'measure',
  'meat',
  'mechanic',
  'medal',
  'media',
  'melody',
  'melt',
  'member',
  'memory',
  'mention',
  'menu',
  'mercy',
  'merge',
  'merit',
  'merry',
  'mesh',
  'message',
  'metal',
  'method',
  'middle',
  'midnight',
  'milk',
  'million',
  'mimic',
  'mind',
  'minimum',
  'minor',
  'minute',
  'miracle',
  'mirror',
  'misery',
  'miss',
  'mistake',
  'mix',
  'mixed',
  'mixture',
  'mobile',
  'model',
  'modify',
  'mom',
  'moment',
  'monitor',
  'monkey',
  'monster',
  'month',
  'moon',
  'moral',
  'more',
  'morning',
  'mosquito',
  'mother',
  'motion',
  'motor',
  'mountain',
  'mouse',
  'move',
  'movie',
  'much',
  'muffin',
  'mule',
  'multiply',
  'muscle',
  'museum',
  'mushroom',
  'music',
  'must',
  'mutual',
  'myself',
  'mystery',
  'myth',
  'naive',
  'name',
  'napkin',
  'narrow',
  'nasty',
  'nation',
  'nature',
  'near',
  'neck',
  'need',
  'negative',
  'neglect',
  'neither',
  'nephew',
  'nerve',
  'nest',
  'net',
  'network',
  'neutral',
  'never',
  'news',
  'next',
  'nice',
  'night',
  'noble',
  'noise',
  'nominee',
  'noodle',
  'normal',
  'north',
  'nose',
  'notable',
  'note',
  'nothing',
  'notice',
  'novel',
  'now',
  'nuclear',
  'number',
  'nurse',
  'nut',
  'oak',
  'obey',
  'object',
  'oblige',
  'obscure',
  'observe',
  'obtain',
  'obvious',
  'occur',
  'ocean',
  'october',
  'odor',
  'off',
  'offer',
  'office',
  'often',
  'oil',
  'okay',
  'old',
  'olive',
  'olympic',
  'omit',
  'once',
  'one',
  'onion',
  'online',
  'only',
  'open',
  'opera',
  'opinion',
  'oppose',
  'option',
  'orange',
  'orbit',
  'orchard',
  'order',
  'ordinary',
  'organ',
  'orient',
  'original',
  'orphan',
  'ostrich',
  'other',
  'outdoor',
  'outer',
  'output',
  'outside',
  'oval',
  'oven',
  'over',
  'own',
  'owner',
  'oxygen',
  'oyster',
  'ozone',
  'pact',
  'paddle',
  'page',
  'pair',
  'palace',
  'palm',
  'panda',
  'panel',
  'panic',
  'panther',
  'paper',
  'parade',
  'parent',
  'park',
  'parrot',
  'party',
  'pass',
  'patch',
  'path',
  'patient',
  'patrol',
  'pattern',
  'pause',
  'pave',
  'payment',
  'peace',
  'peanut',
  'pear',
  'peasant',
  'pelican',
  'pen',
  'penalty',
  'pencil',
  'people',
  'pepper',
  'perfect',
  'permit',
  'person',
  'pet',
  'phone',
  'photo',
  'phrase',
  'physical',
  'piano',
  'picnic',
  'picture',
  'piece',
  'pig',
  'pigeon',
  'pill',
  'pilot',
  'pink',
  'pioneer',
  'pipe',
  'pistol',
  'pitch',
  'pizza',
  'place',
  'planet',
  'plastic',
  'plate',
  'play',
  'please',
  'pledge',
  'pluck',
  'plug',
  'plunge',
  'poem',
  'poet',
  'point',
  'polar',
  'pole',
  'police',
  'pond',
  'pony',
  'pool',
  'popular',
  'portion',
  'position',
  'possible',
  'post',
  'potato',
  'pottery',
  'poverty',
  'powder',
  'power',
  'practice',
  'praise',
  'predict',
  'prefer',
  'prepare',
  'present',
  'pretty',
  'prevent',
  'price',
  'pride',
  'primary',
  'print',
  'priority',
  'prison',
  'private',
  'prize',
  'problem',
  'process',
  'produce',
  'profit',
  'program',
  'project',
  'promote',
  'proof',
  'property',
  'prosper',
  'protect',
  'proud',
  'provide',
  'public',
  'pudding',
  'pull',
  'pulp',
  'pulse',
  'pumpkin',
  'punch',
  'pupil',
  'puppy',
  'purchase',
  'purity',
  'purpose',
  'purse',
  'push',
  'put',
  'puzzle',
  'pyramid',
  'quality',
  'quantum',
  'quarter',
  'question',
  'quick',
  'quit',
  'quiz',
  'quote',
  'rabbit',
  'raccoon',
  'race',
  'rack',
  'radar',
  'radio',
  'rail',
  'rain',
  'raise',
  'rally',
  'ramp',
  'ranch',
  'random',
  'range',
  'rapid',
  'rare',
  'rate',
  'rather',
  'raven',
  'raw',
  'razor',
  'ready',
  'real',
  'reason',
  'rebel',
  'rebuild',
  'recall',
  'receive',
  'recipe',
  'record',
  'recycle',
  'reduce',
  'reflect',
  'reform',
  'refuse',
  'region',
  'regret',
  'regular',
  'reject',
  'relax',
  'release',
  'relief',
  'rely',
  'remain',
  'remember',
  'remind',
  'remove',
  'render',
  'renew',
  'rent',
  'reopen',
  'repair',
  'repeat',
  'replace',
  'report',
  'require',
  'rescue',
  'resemble',
  'resist',
  'resource',
  'response',
  'result',
  'retire',
  'retreat',
  'return',
  'reunion',
  'reveal',
  'review',
  'reward',
  'rhythm',
  'rib',
  'ribbon',
  'rice',
  'rich',
  'ride',
  'ridge',
  'rifle',
  'right',
  'rigid',
  'ring',
  'riot',
  'ripple',
  'risk',
  'ritual',
  'rival',
  'river',
  'road',
  'roast',
  'robot',
  'robust',
  'rocket',
  'romance',
  'roof',
  'rookie',
  'room',
  'rose',
  'rotate',
  'rough',
  'round',
  'route',
  'royal',
  'rubber',
  'rude',
  'rug',
  'rule',
  'run',
  'runway',
  'rural',
  'sad',
  'saddle',
  'sadness',
  'safe',
  'sail',
  'salad',
  'salmon',
  'salon',
  'salt',
  'salute',
  'same',
  'sample',
  'sand',
  'satisfy',
  'satoshi',
  'sauce',
  'sausage',
  'save',
  'say',
  'scale',
  'scan',
  'scare',
  'scatter',
  'scene',
  'scheme',
  'school',
  'science',
  'scissors',
  'scorpion',
  'scout',
  'scrap',
  'screen',
  'script',
  'scrub',
  'sea',
  'search',
  'season',
  'seat',
  'second',
  'secret',
  'section',
  'security',
  'seed',
  'seek',
  'segment',
  'select',
  'sell',
  'seminar',
  'senior',
  'sense',
  'sentence',
  'series',
  'service',
  'session',
  'settle',
  'setup',
  'seven',
  'shadow',
  'shaft',
  'shallow',
  'share',
  'shed',
  'shell',
  'sheriff',
  'shield',
  'shift',
  'shine',
  'ship',
  'shiver',
  'shock',
  'shoe',
  'shoot',
  'shop',
  'short',
  'shoulder',
  'shove',
  'shrimp',
  'shrug',
  'shuffle',
  'shy',
  'sibling',
  'sick',
  'side',
  'siege',
  'sight',
  'sign',
  'silent',
  'silk',
  'silly',
  'silver',
  'similar',
  'simple',
  'since',
  'sing',
  'siren',
  'sister',
  'situate',
  'six',
  'size',
  'skate',
  'sketch',
  'ski',
  'skill',
  'skin',
  'skirt',
  'skull',
  'slab',
  'slam',
  'sleep',
  'slender',
  'slice',
  'slide',
  'slight',
  'slim',
  'slogan',
  'slot',
  'slow',
  'slush',
  'small',
  'smart',
  'smile',
  'smoke',
  'smooth',
  'snack',
  'snake',
  'snap',
  'sniff',
  'snow',
  'soap',
  'soccer',
  'social',
  'sock',
  'soda',
  'soft',
  'solar',
  'soldier',
  'solid',
  'solution',
  'solve',
  'someone',
  'song',
  'soon',
  'sorry',
  'sort',
  'soul',
  'sound',
  'soup',
  'source',
  'south',
  'space',
  'spare',
  'spatial',
  'spawn',
  'speak',
  'special',
  'speed',
  'spell',
  'spend',
  'sphere',
  'spice',
  'spider',
  'spike',
  'spin',
  'spirit',
  'split',
  'spoil',
  'sponsor',
  'spoon',
  'sport',
  'spot',
  'spray',
  'spread',
  'spring',
  'spy',
  'square',
  'squeeze',
  'squirrel',
  'stable',
  'stadium',
  'staff',
  'stage',
  'stairs',
  'stamp',
  'stand',
  'start',
  'state',
  'stay',
  'steak',
  'steel',
  'stem',
  'step',
  'stereo',
  'stick',
  'still',
  'sting',
  'stock',
  'stomach',
  'stone',
  'stool',
  'story',
  'stove',
  'strategy',
  'street',
  'strike',
  'strong',
  'struggle',
  'student',
  'stuff',
  'stumble',
  'style',
  'subject',
  'submit',
  'subway',
  'success',
  'such',
  'sudden',
  'suffer',
  'sugar',
  'suggest',
  'suit',
  'summer',
  'sun',
  'sunny',
  'sunset',
  'super',
  'supply',
  'supreme',
  'sure',
  'surface',
  'surge',
  'surprise',
  'surround',
  'survey',
  'suspect',
  'sustain',
  'swallow',
  'swamp',
  'swap',
  'swarm',
  'swear',
  'sweet',
  'swift',
  'swim',
  'swing',
  'switch',
  'sword',
  'symbol',
  'symptom',
  'syrup',
  'system',
  'table',
  'tackle',
  'tag',
  'tail',
  'talent',
  'talk',
  'tank',
  'tape',
  'target',
  'task',
  'taste',
  'tattoo',
  'taxi',
  'teach',
  'team',
  'tell',
  'ten',
  'tenant',
  'tennis',
  'tent',
  'term',
  'test',
  'text',
  'thank',
  'that',
  'theme',
  'then',
  'theory',
  'there',
  'they',
  'thing',
  'this',
  'thought',
  'three',
  'thrive',
  'throw',
  'thumb',
  'thunder',
  'ticket',
  'tide',
  'tiger',
  'tilt',
  'timber',
  'time',
  'tiny',
  'tip',
  'tired',
  'tissue',
  'title',
  'toast',
  'tobacco',
  'today',
  'toddler',
  'toe',
  'together',
  'toilet',
  'token',
  'tomato',
  'tomorrow',
  'tone',
  'tongue',
  'tonight',
  'tool',
  'tooth',
  'top',
  'topic',
  'topple',
  'torch',
  'tornado',
  'tortoise',
  'toss',
  'total',
  'tourist',
  'toward',
  'tower',
  'town',
  'toy',
  'track',
  'trade',
  'traffic',
  'tragic',
  'train',
  'transfer',
  'trap',
  'trash',
  'travel',
  'tray',
  'treat',
  'tree',
  'trend',
  'trial',
  'tribe',
  'trick',
  'trigger',
  'trim',
  'trip',
  'trophy',
  'trouble',
  'truck',
  'true',
  'truly',
  'trumpet',
  'trust',
  'truth',
  'try',
  'tube',
  'tuition',
  'tumble',
  'tuna',
  'tunnel',
  'turkey',
  'turn',
  'turtle',
  'twelve',
  'twenty',
  'twice',
  'twin',
  'twist',
  'two',
  'type',
  'typical',
  'ugly',
  'umbrella',
  'unable',
  'unaware',
  'uncle',
  'uncover',
  'under',
  'undo',
  'unfair',
  'unfold',
  'unhappy',
  'uniform',
  'unique',
  'unit',
  'universe',
  'unknown',
  'unlock',
  'until',
  'unusual',
  'unveil',
  'update',
  'upgrade',
  'uphold',
  'upon',
  'upper',
  'upset',
  'urban',
  'urge',
  'usage',
  'use',
  'used',
  'useful',
  'useless',
  'usual',
  'utility',
  'vacant',
  'vacuum',
  'vague',
  'valid',
  'valley',
  'valve',
  'van',
  'vanish',
  'vapor',
  'various',
  'vast',
  'vault',
  'vehicle',
  'velvet',
  'vendor',
  'venture',
  'venue',
  'verb',
  'verify',
  'version',
  'very',
  'vessel',
  'veteran',
  'viable',
  'vibrant',
  'vicious',
  'victory',
  'video',
  'view',
  'village',
  'vintage',
  'violin',
  'virtual',
  'virus',
  'visa',
  'visit',
  'visual',
  'vital',
  'vivid',
  'vocal',
  'voice',
  'void',
  'volcano',
  'volume',
  'vote',
  'voyage',
  'wage',
  'wagon',
  'wait',
  'walk',
  'wall',
  'walnut',
  'want',
  'warfare',
  'warm',
  'warrior',
  'wash',
  'wasp',
  'waste',
  'water',
  'wave',
  'way',
  'wealth',
  'weapon',
  'wear',
  'weasel',
  'weather',
  'web',
  'wedding',
  'weekend',
  'weird',
  'welcome',
  'west',
  'wet',
  'whale',
  'what',
  'wheat',
  'wheel',
  'when',
  'where',
  'whip',
  'whisper',
  'wide',
  'width',
  'wife',
  'wild',
  'will',
  'win',
  'window',
  'wine',
  'wing',
  'wink',
  'winner',
  'winter',
  'wire',
  'wisdom',
  'wise',
  'wish',
  'witness',
  'wolf',
  'woman',
  'wonder',
  'wood',
  'wool',
  'word',
  'work',
  'world',
  'worry',
  'worth',
  'wrap',
  'wreck',
  'wrestle',
  'wrist',
  'write',
  'wrong',
  'yard',
  'year',
  'yellow',
  'you',
  'young',
  'youth',
  'zebra',
  'zero',
  'zone',
  'zoo'
];
