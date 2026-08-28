/// Match Word — the curated bank of playable words and the clues for each.
///
/// This is the **single source of truth** for what a game may deal. A word only
/// belongs here if a clue-giver can point at it with a one-word clue that
/// actually narrows it down.
///
/// Why it exists (Ronna, Aug 2026): "when the stand in AI plays, the answers
/// they're giving are not making any sense. And yet often times they tell them
/// they're right. We have to have a word and answer based that is completely
/// sensible."
///
/// The old 1,209-word database was the cause. 1,010 of those words carried a
/// generic category placeholder instead of a clue — 91 words were all clued
/// "Person / Someone / People", 90 were "Place / Spot / Area", and the single
/// clue "Spot" stood for 145 different answers. So a stand-in would say
/// "Person", the guesser would answer "Accountant", and the game scored it
/// correct because it *was* the secret word. Nothing was wrong with the
/// scoring; the clue simply never identified the word.
///
/// Words are grouped into families so that a *wrong* guess can also make sense:
/// a stand-in that misses on "Talons" says another bird, not a random noun.
///
/// Every entry is checked by `test/clue_bank_test.dart`, which enforces:
///  * at least three clues per word,
///  * no clue that repeats, contains, or is contained by its own answer,
///  * no clue that is itself a playable word (otherwise the clue looks like a
///    legitimate answer, and guessing it is a foul),
///  * no clue shared by more than three answers, so a clue always narrows the
///    field, and
///  * no two words sharing an identical clue set.
library;

import 'dart:math';

class ClueBank {
  const ClueBank._();

  /// Family → answer → the one-word clues that point at that answer.
  static const Map<String, Map<String, List<String>>> byFamily = {
    'food': {
      'apple': ['Orchard', 'Cider', 'Crisp'],
      'banana': ['Peel', 'Bunch', 'Split'],
      'bread': ['Loaf', 'Toast', 'Sourdough'],
      'butter': ['Spread', 'Churn', 'Margarine'],
      'cheese': ['Cheddar', 'Grate', 'Dairy'],
      'cookie': ['Crumbs', 'Biscuit', 'Batch'],
      'coffee': ['Beans', 'Espresso', 'Percolator'],
      'tea': ['Steep', 'Herbal', 'Chamomile'],
      'honey': ['Bees', 'Sticky', 'Golden'],
      'lemon': ['Sour', 'Zest', 'Citrus'],
      'soup': ['Ladle', 'Broth', 'Simmer'],
      'pancake': ['Syrup', 'Flip', 'Griddle'],
      'popcorn': ['Kernels', 'Cinema', 'Popping'],
      'sandwich': ['Filling', 'Lunchbox', 'Layered'],
      'pie': ['Crust', 'Rhubarb', 'Latticed'],
      'cake': ['Icing', 'Frosting', 'Tiered'],
      'carrot': ['Root', 'Snowman', 'Peeler'],
      'potato': ['Mash', 'Fries', 'Spud'],
      'tomato': ['Ketchup', 'Vine', 'Salsa'],
      'onion': ['Tears', 'Pungent', 'Chopping'],
      'garlic': ['Cloves', 'Vampire', 'Aromatic'],
      'mushroom': ['Fungus', 'Toadstool', 'Portobello'],
      'strawberry': ['Jam', 'Shortcake', 'Reddish'],
      'grape': ['Winery', 'Raisin', 'Cluster'],
      'pizza': ['Slices', 'Pepperoni', 'Delivery'],
      'pasta': ['Noodles', 'Italian', 'Spaghetti'],
      'rice': ['Grains', 'Steamed', 'Paddy'],
      'egg': ['Yolk', 'Scramble', 'Omelette'],
      'milk': ['Carton', 'Creamy', 'Pasteurized'],
      'salt': ['Shaker', 'Seasoning', 'Briny'],
      'sugar': ['Sweetness', 'Cubes', 'Spoonful'],
      'juice': ['Squeeze', 'Pulp', 'Refreshing'],
      'donut': ['Glazed', 'Sprinkles', 'Ringshaped'],
      'muffin': ['Blueberries', 'Tin', 'Crumbly'],
      'waffle': ['Griddled', 'Belgian', 'Squares'],
      'icecream': ['Cone', 'Sundae', 'Frozen'],
      'chocolate': ['Cocoa', 'Truffle', 'Bittersweet'],
    },
    'animals': {
      'cat': ['Whiskers', 'Purr', 'Feline'],
      'dog': ['Leash', 'Loyal', 'Canine'],
      'horse': ['Saddle', 'Gallop', 'Mane'],
      'cow': ['Moo', 'Udder', 'Grazing'],
      'sheep': ['Wool', 'Flock', 'Baa'],
      'pig': ['Oink', 'Snout', 'Sty'],
      'duck': ['Quack', 'Waddle', 'Mallard'],
      'chicken': ['Cluck', 'Hen', 'Rooster'],
      'rabbit': ['Burrow', 'Hopping', 'Bunny'],
      'mouse': ['Squeak', 'Whiskery', 'Rodent'],
      'squirrel': ['Acorns', 'Treetop', 'Scamper'],
      'owl': ['Hoot', 'Nocturnal', 'Wise'],
      'eagle': ['Talons', 'Soar', 'Majestic'],
      'penguin': ['Antarctic', 'Tuxedo', 'Flipper'],
      'elephant': ['Tusks', 'Enormous', 'Pachyderm'],
      'lion': ['Roaring', 'Pride', 'Savanna'],
      'tiger': ['Stripes', 'Prowl', 'Bengal'],
      'bear': ['Hibernate', 'Grizzly', 'Cub'],
      'fox': ['Sly', 'Den', 'Vixen'],
      'wolf': ['Howl', 'Pack', 'Lone'],
      'frog': ['Croak', 'Amphibian', 'Tadpole'],
      'turtle': ['Slowmoving', 'Tortoise', 'Reptile'],
      'whale': ['Blubber', 'Blowhole', 'Humpback'],
      'dolphin': ['Clicking', 'Porpoise', 'Leaping'],
      'shark': ['Fin', 'Predator', 'Jaws'],
      'crab': ['Pincers', 'Sideways', 'Crustacean'],
      'butterfly': ['Cocoon', 'Flutter', 'Monarch'],
      'bee': ['Hive', 'Pollen', 'Buzzing'],
      'ant': ['Colony', 'Marching', 'Tiny'],
      'spider': ['Web', 'Arachnid', 'Tarantula'],
      'snake': ['Slither', 'Fangs', 'Rattler'],
      'giraffe': ['Tallest', 'Spots', 'Towering'],
      'monkey': ['Mischief', 'Vines', 'Primate'],
      'zebra': ['Africa', 'Striped', 'Herd'],
      'goat': ['Bleat', 'Billy', 'Nanny'],
      'snail': ['Slime', 'Sluggish', 'Shelled'],
    },
    'nature': {
      'rain': ['Drizzle', 'Puddles', 'Downpour'],
      'snow': ['Flakes', 'Blizzard', 'Whiteout'],
      'sun': ['Solar', 'Bright', 'Scorching'],
      'moon': ['Crescent', 'Lunar', 'Tides'],
      'star': ['Twinkle', 'Constellation', 'Stellar'],
      'cloud': ['Fluffy', 'Overcast', 'Cumulus'],
      'wind': ['Gust', 'Blustery', 'Breezy'],
      'storm': ['Brewing', 'Rough', 'Tempest'],
      'rainbow': ['Prism', 'Colorful', 'Arc'],
      'thunder': ['Rumble', 'Boom', 'Clap'],
      'lightning': ['Zigzag', 'Jagged', 'Electric'],
      'fog': ['Misty', 'Hazy', 'Murky'],
      'frost': ['Nippy', 'Icy', 'Crisp'],
      'mountain': ['Peak', 'Summit', 'Alpine'],
      'river': ['Flowing', 'Banks', 'Current'],
      'lake': ['Still', 'Canoe', 'Shoreline'],
      'ocean': ['Waves', 'Salty', 'Vast'],
      'beach': ['Seashore', 'Sunbathe', 'Seashells'],
      'forest': ['Woodland', 'Pines', 'Undergrowth'],
      'garden': ['Weeding', 'Planting', 'Allotment'],
      'flower': ['Petals', 'Bloom', 'Bouquet'],
      'island': ['Surrounded', 'Tropical', 'Castaway'],
      'desert': ['Dunes', 'Camel', 'Arid'],
      'valley': ['Lowland', 'Glen', 'Between'],
      'volcano': ['Erupt', 'Lava', 'Crater'],
      'cave': ['Echo', 'Bats', 'Stalactite'],
    },
    'clothing': {
      'hat': ['Brim', 'Fedora', 'Cap'],
      'coat': ['Parka', 'Buttoned', 'Wintry'],
      'shoe': ['Laces', 'Footwear', 'Cobbler'],
      'sock': ['Toes', 'Woolly', 'Darning'],
      'glove': ['Fingers', 'Mitten', 'Snug'],
      'scarf': ['Knitted', 'Muffler', 'Woven'],
      'shirt': ['Collar', 'Sleeves', 'Ironed'],
      'dress': ['Gown', 'Hemline', 'Elegant'],
      'pants': ['Trousers', 'Belted', 'Slacks'],
      'sweater': ['Pullover', 'Cardigan', 'Woollen'],
      'jacket': ['Windbreaker', 'Outerwear', 'Zipped'],
      'belt': ['Buckle', 'Waist', 'Loops'],
      'purse': ['Handbag', 'Clasp', 'Coins'],
      'apron': ['Strings', 'Messy', 'Bib'],
      'pajama': ['Nightwear', 'Flannel', 'Loungewear'],
    },
    'body': {
      'hand': ['Palm', 'Knuckles', 'Fingernails'],
      'foot': ['Sole', 'Heel', 'Instep'],
      'eye': ['Vision', 'Iris', 'Pupil'],
      'ear': ['Lobe', 'Auditory', 'Listening'],
      'nose': ['Nostrils', 'Sneeze', 'Sniffle'],
      'tooth': ['Enamel', 'Molar', 'Cavity'],
      'hair': ['Salon', 'Curls', 'Combing'],
      'knee': ['Patella', 'Joint', 'Bending'],
      'heart': ['Pulse', 'Cardiac', 'Valentine'],
      'elbow': ['Funnybone', 'Nudge', 'Crook'],
    },
    'family': {
      'mother': ['Mom', 'Maternal', 'Nurturing'],
      'father': ['Dad', 'Paternal', 'Papa'],
      'grandmother': ['Granny', 'Nana', 'Grandma'],
      'grandfather': ['Grandpa', 'Granddad', 'Elder'],
      'sister': ['Sorority', 'Sibling', 'Female'],
      'brother': ['Fraternal', 'Male', 'Kin'],
      'baby': ['Crib', 'Diaper', 'Newborn'],
      'friend': ['Buddy', 'Companion', 'Pal'],
      'neighbor': ['Alongside', 'Nearby', 'Adjacent'],
      'husband': ['Groom', 'Hubby', 'Spouse'],
      'wife': ['Bride', 'Missus', 'Married'],
      'twin': ['Identical', 'Double', 'Matching'],
    },
    'jobs': {
      'doctor': ['Diagnose', 'Physician', 'Prescribe'],
      'nurse': ['Scrubs', 'Bedside', 'Caring'],
      'teacher': ['Chalkboard', 'Grading', 'Schooling'],
      'farmer': ['Crops', 'Overalls', 'Harvesting'],
      'baker': ['Dough', 'Kneading', 'Rolls'],
      'chef': ['Cuisine', 'Culinary', 'Gourmet'],
      'police': ['Siren', 'Patrol', 'Handcuffs'],
      'firefighter': ['Hose', 'Rescue', 'Blaze'],
      'pilot': ['Cockpit', 'Aviator', 'Runway'],
      'carpenter': ['Woodwork', 'Sawdust', 'Joinery'],
      'plumber': ['Pipes', 'Leaks', 'Drains'],
      'barber': ['Haircut', 'Clippers', 'Shave'],
      'dentist': ['Floss', 'Toothache', 'Drilling'],
      'librarian': ['Quiet', 'Cataloguing', 'Overdue'],
      'artist': ['Easel', 'Palette', 'Studio'],
      'musician': ['Band', 'Perform', 'Rehearse'],
      'mechanic': ['Overhaul', 'Grease', 'Repairs'],
      'sailor': ['Deckhand', 'Seafaring', 'Nautical'],
      'soldier': ['Salute', 'Barracks', 'Combat'],
    },
    'places': {
      'school': ['Pupils', 'Recess', 'Homeroom'],
      'hospital': ['Patients', 'Wards', 'Ambulance'],
      'library': ['Silence', 'Lending', 'Reference'],
      'church': ['Pews', 'Steeple', 'Hymns'],
      'market': ['Stalls', 'Produce', 'Vendors'],
      'restaurant': ['Menu', 'Dining', 'Reservation'],
      'hotel': ['Lobby', 'Suites', 'Concierge'],
      'bank': ['Vault', 'Deposit', 'Teller'],
      'museum': ['Exhibits', 'Artifacts', 'Curator'],
      'park': ['Benches', 'Swings', 'Picnicking'],
      'kitchen': ['Cooking', 'Recipes', 'Stovetop'],
      'bedroom': ['Wardrobe', 'Nightstand', 'Slumber'],
      'bathroom': ['Shower', 'Toilet', 'Bathtub'],
      'garage': ['Parking', 'Workbench', 'Carport'],
      'attic': ['Rafters', 'Storage', 'Dusty'],
      'basement': ['Cellar', 'Damp', 'Foundation'],
      'stadium': ['Crowds', 'Bleachers', 'Floodlights'],
      'city': ['Skyscrapers', 'Bustling', 'Urban'],
      'village': ['Hamlet', 'Quaint', 'Rural'],
      'bridge': ['Span', 'Crossing', 'Suspension'],
      'tunnel': ['Bore', 'Passage', 'Underpass'],
      'castle': ['Turrets', 'Moat', 'Fortress'],
    },
    'transport': {
      'car': ['Sedan', 'Motoring', 'Automobile'],
      'bus': ['Passengers', 'Doubledecker', 'Transit'],
      'train': ['Rails', 'Locomotive', 'Carriages'],
      'boat': ['Harbor', 'Dinghy', 'Afloat'],
      'bicycle': ['Pedals', 'Handlebars', 'Cyclist'],
      'motorcycle': ['Throttle', 'Biker', 'Sidecar'],
      'truck': ['Cargo', 'Lorry', 'Hauling'],
      'taxi': ['Fare', 'Cab', 'Hailing'],
      'ship': ['Vessel', 'Freighter', 'Steamer'],
      'tractor': ['Plowing', 'Farmyard', 'Furrow'],
      'wagon': ['Cart', 'Pulled', 'Wheeled'],
      'helicopter': ['Rotor', 'Hover', 'Chopper'],
      'rocket': ['Launch', 'Countdown', 'Orbit'],
    },
    'arts': {
      'piano': ['Ivory', 'Grand', 'Pianist'],
      'guitar': ['Strum', 'Frets', 'Acoustic'],
      'drum': ['Percussion', 'Snare', 'Bongo'],
      'violin': ['Fiddle', 'Orchestra', 'Vibrato'],
      'trumpet': ['Brass', 'Blare', 'Valves'],
      'flute': ['Woodwind', 'Piccolo', 'Fluting'],
      'harp': ['Plucked', 'Angelic', 'Celtic'],
      'song': ['Lyrics', 'Chorus', 'Verse'],
      'book': ['Pages', 'Novelist', 'Hardcover'],
      'movie': ['Blockbuster', 'Screening', 'Matinee'],
      'painting': ['Canvas', 'Masterpiece', 'Brushstrokes'],
    },
    'sport': {
      'football': ['Touchdown', 'Quarterback', 'Gridiron'],
      'baseball': ['Pitcher', 'Innings', 'Homerun'],
      'basketball': ['Hoop', 'Dribble', 'Dunk'],
      'soccer': ['Striker', 'Worldcup', 'Penalty'],
      'tennis': ['Wimbledon', 'Volley', 'Racquet'],
      'golf': ['Clubs', 'Putting', 'Fairway'],
      'hockey': ['Puck', 'Rink', 'Slapshot'],
      'swimming': ['Laps', 'Poolside', 'Backstroke'],
      'fishing': ['Bait', 'Angler', 'Tacklebox'],
      'puzzle': ['Jigsaw', 'Solving', 'Brainteaser'],
      'chess': ['Checkmate', 'Pawns', 'Bishop'],
      'kite': ['Windy', 'Soaring', 'Tailed'],
      'balloon': ['Helium', 'Inflate', 'Burst'],
    },
    'household': {
      'hammer': ['Nails', 'Pounding', 'Mallet'],
      'wrench': ['Bolts', 'Tighten', 'Spanner'],
      'ladder': ['Rungs', 'Ascend', 'Leaning'],
      'shovel': ['Digging', 'Spade', 'Trench'],
      'bucket': ['Pail', 'Brimful', 'Handled'],
      'rope': ['Knot', 'Coil', 'Braided'],
      'key': ['Padlock', 'Unlocking', 'Ignition'],
      'pen': ['Ink', 'Ballpoint', 'Scribble'],
      'pencil': ['Eraser', 'Sharpener', 'Graphite'],
      'needle': ['Sewing', 'Pinprick', 'Haystack'],
      'button': ['Fasten', 'Sewn', 'Toggle'],
      'mirror': ['Reflection', 'Silvered', 'Vanity'],
      'clock': ['Ticking', 'Chimes', 'Alarm'],
      'camera': ['Lens', 'Shutter', 'Photos'],
      'phone': ['Ringing', 'Dial', 'Mobile'],
      'radio': ['Stations', 'Tuning', 'Broadcast'],
      'television': ['Channels', 'Remote', 'Viewing'],
      'computer': ['Monitor', 'Software', 'Desktop'],
      'letter': ['Mailbox', 'Correspondence', 'Postage'],
      'map': ['Directions', 'Atlas', 'Cartography'],
      'money': ['Currency', 'Banknotes', 'Wealth'],
      'watch': ['Timepiece', 'Strap', 'Winding'],
      'candle': ['Wax', 'Wick', 'Flickering'],
      'basket': ['Woven', 'Wicker', 'Hamper'],
      'trophy': ['Champion', 'Engraved', 'Silverware'],
      'blanket': ['Cozy', 'Quilted', 'Bedcover'],
      'pillow': ['Headrest', 'Fluffed', 'Plumped'],
      'broom': ['Bristles', 'Dustpan', 'Sweeping'],
      'towel': ['Drying', 'Terrycloth', 'Absorbent'],
      'curtain': ['Drapes', 'Drawn', 'Pelmet'],
      'lamp': ['Nightlight', 'Bulb', 'Shaded'],
      'oven': ['Baking', 'Roasting', 'Preheat'],
      'spoon': ['Stirring', 'Cutlery', 'Scooping'],
      'fork': ['Prongs', 'Tines', 'Skewering'],
      'knife': ['Sharpened', 'Blade', 'Carving'],
      'plate': ['Ceramic', 'Crockery', 'Platter'],
      'bowl': ['Cereal', 'Mixing', 'Rounded'],
      'kettle': ['Boiling', 'Whistling', 'Spout'],
      'teapot': ['Brewing', 'China', 'Pouring'],
      'window': ['Pane', 'Sill', 'Ledge'],
      'door': ['Knob', 'Hinges', 'Entrance'],
      'roof': ['Shingles', 'Eaves', 'Overhead'],
      'wall': ['Bricks', 'Partition', 'Plaster'],
      'fence': ['Posts', 'Boundary', 'Picket'],
      'chair': ['Seat', 'Armrest', 'Recliner'],
      'table': ['Surface', 'Placemat', 'Furniture'],
      'bed': ['Mattress', 'Headboard', 'Duvet'],
      'box': ['Cardboard', 'Packing', 'Lid'],
      'bottle': ['Cork', 'Glassware', 'Screwtop'],
      'flag': ['Pole', 'Waving', 'Emblem'],
      'ribbon': ['Satin', 'Curled', 'Trim'],
    },
    'occasions': {
      'birthday': ['Candles', 'Presents', 'Wishes'],
      'wedding': ['Vows', 'Bridesmaid', 'Honeymoon'],
      'holiday': ['Vacation', 'Getaway', 'Leave'],
      'morning': ['Dawn', 'Daybreak', 'Early'],
      'evening': ['Dusk', 'Twilight', 'Sundown'],
      'winter': ['Snowy', 'Chilly', 'Coldest'],
      'summer': ['Sunshine', 'Hottest', 'Heatwave'],
      'autumn': ['Falling', 'Pumpkins', 'Harvesttime'],
      'spring': ['Blossom', 'Thaw', 'Renewal'],
    },
  };

  /// Lower-case answer → its clues, flattened across every family.
  static final Map<String, List<String>> clues = {
    for (final family in byFamily.values) ...family,
  };

  static final Map<String, String> _familyOf = {
    for (final entry in byFamily.entries)
      for (final word in entry.value.keys) word: entry.key,
  };

  /// Playable words in display form (title case). Matching is case-insensitive.
  static final List<String> words = [
    for (final w in clues.keys) w[0].toUpperCase() + w.substring(1),
  ];

  static String _key(String word) => word.trim().toLowerCase();

  /// Clues for [word], or an empty list when the word is not in the bank.
  static List<String> cluesFor(String word) => clues[_key(word)] ?? const [];

  /// True when [word] can be clued sensibly, so it is safe to deal.
  static bool isPlayable(String word) => cluesFor(word).isNotEmpty;

  /// The other answers in [word]'s family, in display form. A stand-in's wrong
  /// guess comes from here so a miss still sounds like someone playing along.
  static List<String> siblingsOf(String word) {
    final family = byFamily[_familyOf[_key(word)]];
    if (family == null) return const [];
    return [
      for (final w in family.keys)
        if (w != _key(word)) w[0].toUpperCase() + w.substring(1),
    ];
  }

  /// Returns [count] distinct words in random order.
  static List<String> deal(int count, {Random? random}) {
    final pool = List<String>.of(words)..shuffle(random ?? Random());
    if (count <= pool.length) return pool.take(count).toList();
    final out = <String>[];
    for (var i = 0; out.length < count; i++) {
      out.add(pool[i % pool.length]);
    }
    return out;
  }
}
