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
/// Every word carries [cluesPerWord] clues, one for each exchange a word can
/// run to (`MatchConfig.maxExchanges`). A clue may not be repeated on a word, so
/// a word with fewer clues than that would run dry mid-round and fall back to a
/// meaningless nudge — reintroducing the very problem this file exists to fix.
///
/// Words are grouped into families so that a *wrong* guess can also make sense:
/// a stand-in that misses on "Talons" says another bird, not a random noun.
///
/// Every entry is checked by `test/clue_bank_test.dart`, which enforces:
///  * [cluesPerWord] clues per word,
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

  /// Clues held for every word — one per exchange a word can run to.
  ///
  /// Must stay >= `MatchConfig.maxExchanges`, which `clue_bank_test.dart`
  /// asserts.
  static const int cluesPerWord = 5;

  /// Family → answer → the one-word clues that point at it.
  static const Map<String, Map<String, List<String>>> byFamily = {
    'food': {
      'apple': ['Orchard', 'Cider', 'Crisp', 'Core', 'Braeburn'],
      'banana': ['Peel', 'Bunch', 'Split', 'Slippery', 'Curved'],
      'bread': ['Loaf', 'Toast', 'Sourdough', 'Crusty', 'Baguette'],
      'butter': ['Spread', 'Churn', 'Margarine', 'Creamery', 'Melts'],
      'cheese': ['Cheddar', 'Grate', 'Dairy', 'Swiss', 'Parmesan'],
      'cookie': ['Crumbs', 'Biscuit', 'Batch', 'Oatmeal', 'Dunk'],
      'coffee': ['Beans', 'Espresso', 'Percolator', 'Latte', 'Caffeine'],
      'tea': ['Steep', 'Herbal', 'Chamomile', 'Earlgrey', 'Infusion'],
      'honey': ['Bees', 'Sticky', 'Golden', 'Nectar', 'Syrupy'],
      'lemon': ['Sour', 'Zest', 'Citrus', 'Tart', 'Rind'],
      'soup': ['Ladle', 'Broth', 'Simmer', 'Bisque', 'Chowder'],
      'pancake': ['Syrup', 'Flip', 'Griddle', 'Batter', 'Stack'],
      'popcorn': ['Kernels', 'Cinema', 'Popping', 'Buttery', 'Munching'],
      'sandwich': ['Filling', 'Lunchbox', 'Layered', 'Deli', 'Triangles'],
      'pie': ['Crust', 'Rhubarb', 'Latticed', 'Pastry', 'Wedge'],
      'cake': ['Icing', 'Frosting', 'Tiered', 'Sponge', 'Buttercream'],
      'carrot': ['Root', 'Snowman', 'Peeler', 'Grated', 'Stick'],
      'potato': ['Mash', 'Fries', 'Spud', 'Baked', 'Chips'],
      'tomato': ['Ketchup', 'Vine', 'Salsa', 'Marinara', 'Ripe'],
      'onion': ['Tears', 'Pungent', 'Chopping', 'Bulb', 'Caramelized'],
      'garlic': ['Cloves', 'Vampire', 'Aromatic', 'Bulbous', 'Breath'],
      'mushroom': ['Fungus', 'Toadstool', 'Portobello', 'Spore', 'Woodsy'],
      'strawberry': ['Jam', 'Shortcake', 'Reddish', 'Hulled', 'Ripened'],
      'grape': ['Winery', 'Raisin', 'Cluster', 'Vineyard', 'Seedless'],
      'pizza': ['Slices', 'Pepperoni', 'Delivery', 'Margherita', 'Takeaway'],
      'pasta': ['Noodles', 'Italian', 'Spaghetti', 'Penne', 'Alfredo'],
      'rice': ['Grains', 'Steamed', 'Paddy', 'Risotto', 'Basmati'],
      'egg': ['Yolk', 'Scramble', 'Omelette', 'Poached', 'Whisk'],
      'milk': ['Carton', 'Creamy', 'Pasteurized', 'Skimmed', 'Frothed'],
      'salt': ['Shaker', 'Seasoning', 'Briny', 'Sodium', 'Sprinkle'],
      'sugar': ['Sweetness', 'Cubes', 'Spoonful', 'Sucrose', 'Granulated'],
      'juice': ['Squeeze', 'Pulp', 'Refreshing', 'Freshly', 'Concentrate'],
      'donut': ['Glazed', 'Sprinkles', 'Ringshaped', 'Krispy', 'Fried'],
      'muffin': ['Blueberries', 'Tin', 'Crumbly', 'Bran', 'Cupcake'],
      'waffle': ['Griddled', 'Belgian', 'Squares', 'Maple', 'Crispy'],
      'icecream': ['Cone', 'Sundae', 'Frozen', 'Vanilla', 'Melting'],
      'chocolate': ['Cocoa', 'Truffle', 'Bittersweet', 'Fudge', 'Praline'],
    },
    'animals': {
      'cat': ['Whiskers', 'Purr', 'Feline', 'Kitten', 'Meow'],
      'dog': ['Leash', 'Loyal', 'Canine', 'Puppy', 'Fetch'],
      'horse': ['Saddle', 'Gallop', 'Mane', 'Stallion', 'Hooves'],
      'cow': ['Moo', 'Udder', 'Grazing', 'Heifer', 'Cattle'],
      'sheep': ['Wool', 'Flock', 'Baa', 'Lamb', 'Shearing'],
      'pig': ['Oink', 'Snout', 'Sty', 'Trotters', 'Bacon'],
      'duck': ['Quack', 'Waddle', 'Mallard', 'Webbed', 'Drake'],
      'chicken': ['Cluck', 'Hen', 'Rooster', 'Poultry', 'Nugget'],
      'rabbit': ['Burrow', 'Hopping', 'Bunny', 'Warren', 'Fluffy'],
      'mouse': ['Squeak', 'Whiskery', 'Rodent', 'Nibble', 'Vermin'],
      'squirrel': ['Acorns', 'Treetop', 'Scamper', 'Nuts', 'Bushy'],
      'owl': ['Hoot', 'Nocturnal', 'Wise', 'Perched', 'Screech'],
      'eagle': ['Talons', 'Soar', 'Majestic', 'Bald', 'Aerie'],
      'penguin': ['Antarctic', 'Tuxedo', 'Flipper', 'Waddling', 'Iceberg'],
      'elephant': ['Tusks', 'Enormous', 'Pachyderm', 'Ivory', 'Memory'],
      'lion': ['Roaring', 'Pride', 'Savanna', 'Cub', 'Maned'],
      'tiger': ['Stripes', 'Prowl', 'Bengal', 'Feral', 'Jungle'],
      'bear': ['Hibernate', 'Grizzly', 'Polar', 'Growl', 'Cub'],
      'fox': ['Sly', 'Den', 'Vixen', 'Cunning', 'Russet'],
      'wolf': ['Howl', 'Pack', 'Lone', 'Timber', 'Lupine'],
      'frog': ['Croak', 'Amphibian', 'Tadpole', 'Ribbit', 'Pondside'],
      'turtle': ['Slowmoving', 'Tortoise', 'Reptile', 'Carapace', 'Terrapin'],
      'whale': ['Blubber', 'Blowhole', 'Humpback', 'Breach', 'Baleen'],
      'dolphin': ['Clicking', 'Porpoise', 'Leaping', 'Sonar', 'Playful'],
      'shark': ['Fin', 'Predator', 'Jaws', 'Reef', 'Toothy'],
      'crab': ['Pincers', 'Sideways', 'Crustacean', 'Claws', 'Rockpool'],
      'butterfly': ['Cocoon', 'Flutter', 'Monarch', 'Chrysalis', 'Wings'],
      'bee': ['Hive', 'Pollen', 'Buzzing', 'Honeycomb', 'Sting'],
      'ant': ['Colony', 'Marching', 'Tiny', 'Worker', 'Formic'],
      'spider': ['Web', 'Arachnid', 'Tarantula', 'Cobweb', 'Eightlegged'],
      'snake': ['Slither', 'Fangs', 'Rattler', 'Venom', 'Coiled'],
      'giraffe': ['Tallest', 'Spots', 'Towering', 'Longnecked', 'Leggy'],
      'monkey': ['Mischief', 'Vines', 'Primate', 'Swinging', 'Chimp'],
      'zebra': ['Africa', 'Striped', 'Herd', 'Safari', 'Equine'],
      'goat': ['Bleat', 'Billy', 'Nanny', 'Horned', 'Kid'],
      'snail': ['Slime', 'Sluggish', 'Shelled', 'Trail', 'Creeping'],
    },
    'nature': {
      'rain': ['Drizzle', 'Puddles', 'Downpour', 'Showers', 'Umbrella'],
      'snow': ['Flakes', 'Blizzard', 'Whiteout', 'Shovelled', 'Drift'],
      'sun': ['Solar', 'Bright', 'Scorching', 'Rays', 'Daylight'],
      'moon': ['Crescent', 'Lunar', 'Tides', 'Craters', 'Orbiting'],
      'star': ['Twinkle', 'Constellation', 'Stellar', 'Shooting', 'Nightsky'],
      'cloud': ['Fluffy', 'Overcast', 'Cumulus', 'Drifting', 'Skyborne'],
      'wind': ['Gust', 'Blustery', 'Breezy', 'Draught', 'Gale'],
      'storm': ['Brewing', 'Rough', 'Tempest', 'Squall', 'Battening'],
      'rainbow': ['Prism', 'Colorful', 'Arc', 'Sevenhued', 'Pot'],
      'thunder': ['Rumble', 'Boom', 'Clap', 'Growling', 'Roll'],
      'lightning': ['Zigzag', 'Jagged', 'Electric', 'Bolt', 'Flash'],
      'fog': ['Misty', 'Hazy', 'Murky', 'Pea', 'Rolling'],
      'frost': ['Nippy', 'Icy', 'Crisp', 'Rime', 'Windowpanes'],
      'mountain': ['Peak', 'Summit', 'Alpine', 'Range', 'Everest'],
      'river': ['Flowing', 'Banks', 'Current', 'Estuary', 'Rapids'],
      'lake': ['Still', 'Canoe', 'Shoreline', 'Loch', 'Reservoir'],
      'ocean': ['Waves', 'Salty', 'Vast', 'Depths', 'Atlantic'],
      'beach': ['Seashore', 'Sunbathe', 'Seashells', 'Sandy', 'Deckchair'],
      'forest': ['Woodland', 'Pines', 'Undergrowth', 'Trees', 'Canopy'],
      'garden': ['Weeding', 'Planting', 'Allotment', 'Hedge', 'Greenfingers'],
      'flower': ['Petals', 'Bloom', 'Bouquet', 'Blossoming', 'Vase'],
      'island': ['Surrounded', 'Tropical', 'Castaway', 'Isle', 'Atoll'],
      'desert': ['Dunes', 'Camel', 'Arid', 'Sahara', 'Oasis'],
      'valley': ['Lowland', 'Glen', 'Between', 'Dale', 'Gorge'],
      'volcano': ['Erupt', 'Lava', 'Crater', 'Magma', 'Vesuvius'],
      'cave': ['Echo', 'Bats', 'Stalactite', 'Hollow', 'Spelunking'],
    },
    'clothing': {
      'hat': ['Brim', 'Fedora', 'Cap', 'Headgear', 'Doffed'],
      'coat': ['Parka', 'Buttoned', 'Wintry', 'Overgarment', 'Lapel'],
      'shoe': ['Laces', 'Footwear', 'Cobbler', 'Pair', 'Heeled'],
      'sock': ['Toes', 'Woolly', 'Darning', 'Ankle', 'Pairs'],
      'glove': ['Fingers', 'Mitten', 'Snug', 'Handwarmer', 'Boxing'],
      'scarf': ['Knitted', 'Muffler', 'Woven', 'Neckwrap', 'Tartan'],
      'shirt': ['Collar', 'Sleeves', 'Ironed', 'Cuffs', 'Tucked'],
      'dress': ['Gown', 'Hemline', 'Elegant', 'Frock', 'Twirl'],
      'pants': ['Trousers', 'Belted', 'Slacks', 'Legwear', 'Pockets'],
      'sweater': ['Pullover', 'Cardigan', 'Woollen', 'Jumper', 'Knitwear'],
      'jacket': ['Windbreaker', 'Outerwear', 'Zipped', 'Blazer', 'Bomber'],
      'belt': ['Buckle', 'Waist', 'Loops', 'Notch', 'Cinch'],
      'purse': ['Handbag', 'Clasp', 'Coins', 'Strapped', 'Clutch'],
      'apron': ['Strings', 'Messy', 'Bib', 'Pinafore', 'Floury'],
      'pajama': ['Nightwear', 'Flannel', 'Loungewear', 'Bedtime', 'Onesie'],
    },
    'body': {
      'hand': ['Palm', 'Knuckles', 'Fingernails', 'Wave', 'Grip'],
      'foot': ['Sole', 'Heel', 'Instep', 'Arch', 'Step'],
      'eye': ['Vision', 'Iris', 'Pupil', 'Blink', 'Retina'],
      'ear': ['Lobe', 'Auditory', 'Listening', 'Wax', 'Cochlea'],
      'nose': ['Nostrils', 'Sneeze', 'Sniffle', 'Smell', 'Nasal'],
      'tooth': ['Enamel', 'Molar', 'Cavity', 'Incisor', 'Bite'],
      'hair': ['Salon', 'Curls', 'Combing', 'Strands', 'Shampoo'],
      'knee': ['Patella', 'Joint', 'Bending', 'Genuflect', 'Hinge'],
      'heart': ['Pulse', 'Cardiac', 'Valentine', 'Beating', 'Ventricle'],
      'elbow': ['Funnybone', 'Nudge', 'Crook', 'Jab', 'Bendy'],
    },
    'family': {
      'mother': ['Mom', 'Maternal', 'Nurturing', 'Mum', 'Matriarch'],
      'father': ['Dad', 'Paternal', 'Papa', 'Pop', 'Patriarch'],
      'grandmother': ['Granny', 'Nana', 'Grandma', 'Nan', 'Knitting'],
      'grandfather': ['Grandpa', 'Granddad', 'Elder', 'Gramps', 'Pops'],
      'sister': ['Sorority', 'Sibling', 'Female', 'Kinswoman', 'Younger'],
      'brother': ['Fraternal', 'Male', 'Kin', 'Sibship', 'Older'],
      'baby': ['Crib', 'Diaper', 'Newborn', 'Infant', 'Rattle'],
      'friend': ['Buddy', 'Companion', 'Pal', 'Mate', 'Chum'],
      'neighbor': ['Alongside', 'Nearby', 'Adjacent', 'Nextdoor', 'Local'],
      'husband': ['Groom', 'Hubby', 'Spouse', 'Married', 'Mister'],
      'wife': ['Bride', 'Missus', 'Madam', 'Betrothed', 'Spousal'],
      'twin': ['Identical', 'Double', 'Matching', 'Duo', 'Womb'],
    },
    'jobs': {
      'doctor': [
        'Diagnose',
        'Physician',
        'Prescribe',
        'Surgery',
        'Stethoscope'
      ],
      'nurse': ['Scrubs', 'Bedside', 'Caring', 'Ward', 'Matron'],
      'teacher': ['Chalkboard', 'Grading', 'Schooling', 'Lessons', 'Tutor'],
      'farmer': ['Crops', 'Overalls', 'Harvesting', 'Livestock', 'Fields'],
      'baker': ['Dough', 'Kneading', 'Rolls', 'Ovenmitts', 'Yeast'],
      'chef': ['Cuisine', 'Culinary', 'Gourmet', 'Toque', 'Sauces'],
      'police': ['Siren', 'Patrol', 'Handcuffs', 'Constable', 'Beat'],
      'firefighter': ['Hose', 'Rescue', 'Blaze', 'Extinguish', 'Engine'],
      'pilot': ['Cockpit', 'Aviator', 'Runway', 'Wings', 'Altitude'],
      'carpenter': ['Woodwork', 'Sawdust', 'Joinery', 'Chisel', 'Planing'],
      'plumber': ['Pipes', 'Leaks', 'Drains', 'Faucet', 'Plunger'],
      'barber': ['Haircut', 'Clippers', 'Shave', 'Shears', 'Sideburns'],
      'dentist': ['Floss', 'Toothache', 'Drilling', 'Braces', 'Rinse'],
      'librarian': ['Quiet', 'Cataloguing', 'Overdue', 'Stamping', 'Shelving'],
      'artist': ['Easel', 'Palette', 'Studio', 'Sketching', 'Gallery'],
      'musician': ['Band', 'Perform', 'Rehearse', 'Gig', 'Instrumentalist'],
      'mechanic': ['Overhaul', 'Grease', 'Repairs', 'Spanners', 'Bonnet'],
      'sailor': ['Deckhand', 'Seafaring', 'Nautical', 'Mast', 'Voyage'],
      'soldier': ['Salute', 'Barracks', 'Combat', 'Regiment', 'Infantry'],
    },
    'places': {
      'school': ['Pupils', 'Recess', 'Homeroom', 'Classroom', 'Playtime'],
      'hospital': ['Patients', 'Wards', 'Ambulance', 'Casualty', 'Bedpan'],
      'library': [
        'Silence',
        'Lending',
        'Reference',
        'Borrowing',
        'Bookshelves'
      ],
      'church': ['Pews', 'Steeple', 'Hymns', 'Altar', 'Congregation'],
      'market': ['Stalls', 'Produce', 'Vendors', 'Haggling', 'Bazaar'],
      'restaurant': ['Menu', 'Dining', 'Reservation', 'Waiter', 'Bistro'],
      'hotel': ['Lobby', 'Suites', 'Concierge', 'Checkin', 'Bellboy'],
      'bank': ['Vault', 'Deposit', 'Teller', 'Withdraw', 'Cashpoint'],
      'museum': ['Exhibits', 'Artifacts', 'Curator', 'Displays', 'Antiquities'],
      'park': ['Benches', 'Swings', 'Picnicking', 'Greenery', 'Bandstand'],
      'kitchen': ['Cooking', 'Recipes', 'Stovetop', 'Pantry', 'Worktop'],
      'bedroom': ['Wardrobe', 'Nightstand', 'Slumber', 'Dresser', 'Boudoir'],
      'bathroom': ['Shower', 'Toilet', 'Bathtub', 'Washbasin', 'Loo'],
      'garage': ['Parking', 'Workbench', 'Carport', 'Driveway', 'Toolshed'],
      'attic': ['Rafters', 'Storage', 'Dusty', 'Loft', 'Trapdoor'],
      'basement': ['Cellar', 'Damp', 'Foundation', 'Underground', 'Boiler'],
      'stadium': ['Crowds', 'Bleachers', 'Floodlights', 'Terraces', 'Kickoff'],
      'city': ['Skyscrapers', 'Bustling', 'Urban', 'Metropolis', 'Downtown'],
      'village': ['Hamlet', 'Quaint', 'Rural', 'Parish', 'Countryside'],
      'bridge': ['Span', 'Crossing', 'Suspension', 'Archway', 'Toll'],
      'tunnel': ['Bore', 'Passage', 'Underpass', 'Subterranean', 'Digthrough'],
      'castle': ['Turrets', 'Moat', 'Fortress', 'Drawbridge', 'Battlements'],
    },
    'transport': {
      'car': ['Sedan', 'Motoring', 'Automobile', 'Steering', 'Hatchback'],
      'bus': [
        'Passengers',
        'Doubledecker',
        'Transit',
        'Conductor',
        'Timetable'
      ],
      'train': ['Rails', 'Locomotive', 'Carriages', 'Platform', 'Sleeper'],
      'boat': ['Harbor', 'Dinghy', 'Afloat', 'Oars', 'Moored'],
      'bicycle': ['Pedals', 'Handlebars', 'Cyclist', 'Spokes', 'Tandem'],
      'motorcycle': ['Throttle', 'Biker', 'Sidecar', 'Revving', 'Leathers'],
      'truck': ['Cargo', 'Lorry', 'Hauling', 'Trailer', 'Freight'],
      'taxi': ['Fare', 'Cab', 'Hailing', 'Meter', 'Rank'],
      'ship': ['Vessel', 'Freighter', 'Steamer', 'Bow', 'Anchor'],
      'tractor': ['Plowing', 'Farmyard', 'Furrow', 'Baler', 'Combine'],
      'wagon': ['Cart', 'Pulled', 'Wheeled', 'Hayride', 'Chuck'],
      'helicopter': ['Rotor', 'Hover', 'Chopper', 'Blades', 'Whirly'],
      'rocket': ['Launch', 'Countdown', 'Orbit', 'Booster', 'Liftoff'],
    },
    'arts': {
      'piano': ['Ivory', 'Grand', 'Pianist', 'Sonata', 'Upright'],
      'guitar': ['Strum', 'Frets', 'Acoustic', 'Chords', 'Plectrum'],
      'drum': ['Percussion', 'Snare', 'Bongo', 'Beating', 'Kit'],
      'violin': ['Fiddle', 'Orchestra', 'Vibrato', 'Bowed', 'Stradivarius'],
      'trumpet': ['Brass', 'Blare', 'Valves', 'Fanfare', 'Bugle'],
      'flute': ['Woodwind', 'Piccolo', 'Fluting', 'Breathy', 'Recorder'],
      'harp': ['Plucked', 'Angelic', 'Celtic', 'Strings', 'Concert'],
      'song': ['Lyrics', 'Chorus', 'Verse', 'Melody', 'Singalong'],
      'book': ['Pages', 'Novelist', 'Hardcover', 'Chapters', 'Reading'],
      'movie': ['Blockbuster', 'Screening', 'Matinee', 'Film', 'Director'],
      'painting': ['Canvas', 'Masterpiece', 'Brushstrokes', 'Portrait', 'Oils'],
    },
    'sport': {
      'football': ['Touchdown', 'Quarterback', 'Gridiron', 'Helmet', 'Tackle'],
      'baseball': ['Pitcher', 'Innings', 'Homerun', 'Diamond', 'Mitt'],
      'basketball': ['Hoop', 'Dribble', 'Dunk', 'Freethrow', 'Court'],
      'soccer': ['Striker', 'Worldcup', 'Penalty', 'Offside', 'Pitch'],
      'tennis': ['Wimbledon', 'Volley', 'Racquet', 'Baseline', 'Deuce'],
      'golf': ['Clubs', 'Putting', 'Fairway', 'Birdie', 'Bunker'],
      'hockey': ['Puck', 'Rink', 'Slapshot', 'Stickhandle', 'Faceoff'],
      'swimming': ['Laps', 'Poolside', 'Backstroke', 'Goggles', 'Lengths'],
      'fishing': ['Bait', 'Angler', 'Tacklebox', 'Reel', 'Catch'],
      'puzzle': ['Jigsaw', 'Solving', 'Brainteaser', 'Riddle', 'Pieces'],
      'chess': ['Checkmate', 'Pawns', 'Bishop', 'Rook', 'Grandmaster'],
      'kite': ['Windy', 'Soaring', 'Tailed', 'Flying', 'Highflier'],
      'balloon': ['Helium', 'Inflate', 'Burst', 'Party', 'Floating'],
    },
    'household': {
      'hammer': ['Nails', 'Pounding', 'Mallet', 'Claw', 'Toolbox'],
      'wrench': ['Bolts', 'Tighten', 'Spanner', 'Adjustable', 'Plumbing'],
      'ladder': ['Rungs', 'Ascend', 'Leaning', 'Steps', 'Extension'],
      'shovel': ['Digging', 'Spade', 'Trench', 'Scoop', 'Snowclearing'],
      'bucket': ['Pail', 'Brimful', 'Handled', 'Sloshing', 'Galvanised'],
      'rope': ['Knot', 'Coil', 'Braided', 'Tugofwar', 'Hemp'],
      'key': ['Padlock', 'Unlocking', 'Ignition', 'Turning', 'Cut'],
      'pen': ['Ink', 'Ballpoint', 'Scribble', 'Nib', 'Biro'],
      'pencil': ['Eraser', 'Sharpener', 'Graphite', 'Lead', 'Blunt'],
      'needle': ['Sewing', 'Pinprick', 'Haystack', 'Thread', 'Stitching'],
      'button': ['Fasten', 'Sewn', 'Toggle', 'Undone', 'Fly'],
      'mirror': ['Reflection', 'Silvered', 'Vanity', 'Glassy', 'Selfie'],
      'clock': ['Ticking', 'Chimes', 'Alarm', 'Hands', 'Cuckoo'],
      'camera': ['Lens', 'Shutter', 'Photos', 'Snapshot', 'Zoom'],
      'phone': ['Ringing', 'Dial', 'Mobile', 'Handset', 'Texting'],
      'radio': ['Stations', 'Tuning', 'Broadcast', 'Airwaves', 'Transistor'],
      'television': ['Channels', 'Remote', 'Viewing', 'Screen', 'Telly'],
      'computer': ['Monitor', 'Software', 'Desktop', 'Laptop', 'Processor'],
      'letter': ['Mailbox', 'Correspondence', 'Postage', 'Envelope', 'Stamped'],
      'map': ['Directions', 'Atlas', 'Cartography', 'Route', 'Compass'],
      'money': ['Currency', 'Banknotes', 'Wealth', 'Cash', 'Coinage'],
      'watch': ['Timepiece', 'Strap', 'Winding', 'Wristband', 'Rolex'],
      'candle': ['Wax', 'Wick', 'Flickering', 'Flame', 'Snuffed'],
      'basket': ['Woven', 'Wicker', 'Hamper', 'Weave', 'Laundry'],
      'trophy': ['Champion', 'Engraved', 'Silverware', 'Podium', 'Cabinet'],
      'blanket': ['Cozy', 'Quilted', 'Bedcover', 'Throw', 'Snuggle'],
      'pillow': ['Headrest', 'Fluffed', 'Plumped', 'Feathers', 'Cushion'],
      'broom': ['Bristles', 'Dustpan', 'Sweeping', 'Witch', 'Straw'],
      'towel': ['Drying', 'Terrycloth', 'Absorbent', 'Bathtime', 'Rail'],
      'curtain': ['Drapes', 'Drawn', 'Pelmet', 'Netting', 'Pulled'],
      'lamp': ['Nightlight', 'Bulb', 'Shaded', 'Switch', 'Standard'],
      'oven': ['Baking', 'Roasting', 'Preheat', 'Gasmark', 'Casserole'],
      'spoon': ['Stirring', 'Cutlery', 'Scooping', 'Wooden', 'Dessert'],
      'fork': ['Prongs', 'Tines', 'Skewering', 'Spear', 'Stabbing'],
      'knife': ['Sharpened', 'Blade', 'Carving', 'Cutting', 'Whittle'],
      'plate': ['Ceramic', 'Crockery', 'Platter', 'Dinnerware', 'Washingup'],
      'bowl': ['Cereal', 'Mixing', 'Rounded', 'Salad', 'Serving'],
      'kettle': ['Boiling', 'Whistling', 'Spout', 'Descale', 'Cuppa'],
      'teapot': ['Brewing', 'China', 'Pouring', 'Infuser', 'Cosy'],
      'window': ['Pane', 'Sill', 'Ledge', 'Glazing', 'Curtained'],
      'door': ['Knob', 'Hinges', 'Entrance', 'Slam', 'Ajar'],
      'roof': ['Shingles', 'Eaves', 'Overhead', 'Slates', 'Thatch'],
      'wall': ['Bricks', 'Partition', 'Plaster', 'Mortar', 'Mural'],
      'fence': ['Posts', 'Boundary', 'Picket', 'Palings', 'Railings'],
      'chair': ['Seat', 'Armrest', 'Recliner', 'Sitting', 'Stool'],
      'table': ['Surface', 'Placemat', 'Furniture', 'Diningset', 'Legs'],
      'bed': ['Mattress', 'Headboard', 'Duvet', 'Sleeping', 'Bunk'],
      'box': ['Cardboard', 'Packing', 'Lid', 'Crate', 'Sealed'],
      'bottle': ['Cork', 'Glassware', 'Screwtop', 'Fizzy', 'Recycling'],
      'flag': ['Pole', 'Waving', 'Emblem', 'Banner', 'Hoisted'],
      'ribbon': ['Satin', 'Curled', 'Trim', 'Bowtied', 'Giftwrap'],
    },
    'occasions': {
      'birthday': ['Candles', 'Presents', 'Wishes', 'Celebration', 'Age'],
      'wedding': ['Vows', 'Bridesmaid', 'Honeymoon', 'Aisle', 'Confetti'],
      'holiday': ['Vacation', 'Getaway', 'Leave', 'Suitcase', 'Resort'],
      'morning': ['Dawn', 'Daybreak', 'Early', 'Sunrise', 'Breakfast'],
      'evening': ['Dusk', 'Twilight', 'Sundown', 'Nightfall', 'Supper'],
      'winter': ['Snowy', 'Chilly', 'Coldest', 'Frosty', 'Hibernation'],
      'summer': ['Sunshine', 'Hottest', 'Heatwave', 'Warmest', 'Solstice'],
      'autumn': ['Falling', 'Pumpkins', 'Harvesttime', 'Leaves', 'Equinox'],
      'spring': ['Blossom', 'Thaw', 'Renewal', 'Sprouting', 'Daffodils'],
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
