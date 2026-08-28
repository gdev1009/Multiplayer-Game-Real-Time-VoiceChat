-- =============================================================================
-- 0032_clue_safe_word_bank.sql
-- =============================================================================
-- Deal only words that can actually be clued.
--
-- Ronna (Aug 2026): "when the stand in AI plays, the answers they're giving are
-- not making any sense. And yet often times they tell them they're right. We
-- have to have a word and answer based that is completely sensible."
--
-- Root cause: 0027 deals from Ronna's full Word Database v1 (1,209 words), but
-- 1,010 of those words only ever had a generic category placeholder for a clue.
-- 91 words were all clued "Person / Someone / People", 90 were
-- "Place / Spot / Area", and the single clue "Spot" stood for 145 different
-- answers. A stand-in would say "Person", the guesser would answer
-- "Accountant", and the round scored correct because it *was* the secret word.
-- The scoring was right; the clue never identified the word.
--
-- This bank is the 274 words that have real, distinguishing clues. It is
-- generated from `app/lib/features/game/clue_bank.dart` — the two must stay in
-- step, which `app/test/clue_bank_test.dart` asserts. A game needs 16 words, so
-- 274 still gives plenty of variety.

create or replace function public.mw_begin_play(p_game uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_host   uuid;
  v_status text;
  v_wph    int  := 8;
  v_total  int;
  v_team   text;
  i        int := 0;
  v_word   text;
  v_bank   text[] := array[
    'Ant','Apple','Apron','Artist','Attic','Autumn','Baby','Baker',
    'Balloon','Banana','Bank','Barber','Baseball','Basement','Basket','Basketball',
    'Bathroom','Beach','Bear','Bed','Bedroom','Bee','Belt','Bicycle',
    'Birthday','Blanket','Boat','Book','Bottle','Bowl','Box','Bread',
    'Bridge','Broom','Brother','Bucket','Bus','Butter','Butterfly','Button',
    'Cake','Camera','Candle','Car','Carpenter','Carrot','Castle','Cat',
    'Cave','Chair','Cheese','Chef','Chess','Chicken','Chocolate','Church',
    'City','Clock','Cloud','Coat','Coffee','Computer','Cookie','Cow',
    'Crab','Curtain','Dentist','Desert','Doctor','Dog','Dolphin','Donut',
    'Door','Dress','Drum','Duck','Eagle','Ear','Egg','Elbow',
    'Elephant','Evening','Eye','Farmer','Father','Fence','Firefighter','Fishing',
    'Flag','Flower','Flute','Fog','Foot','Football','Forest','Fork',
    'Fox','Friend','Frog','Frost','Garage','Garden','Garlic','Giraffe',
    'Glove','Goat','Golf','Grandfather','Grandmother','Grape','Guitar','Hair',
    'Hammer','Hand','Harp','Hat','Heart','Helicopter','Hockey','Holiday',
    'Honey','Horse','Hospital','Hotel','Husband','Icecream','Island','Jacket',
    'Juice','Kettle','Key','Kitchen','Kite','Knee','Knife','Ladder',
    'Lake','Lamp','Lemon','Letter','Librarian','Library','Lightning','Lion',
    'Map','Market','Mechanic','Milk','Mirror','Money','Monkey','Moon',
    'Morning','Mother','Motorcycle','Mountain','Mouse','Movie','Muffin','Museum',
    'Mushroom','Musician','Needle','Neighbor','Nose','Nurse','Ocean','Onion',
    'Oven','Owl','Painting','Pajama','Pancake','Pants','Park','Pasta',
    'Pen','Pencil','Penguin','Phone','Piano','Pie','Pig','Pillow',
    'Pilot','Pizza','Plate','Plumber','Police','Popcorn','Potato','Purse',
    'Puzzle','Rabbit','Radio','Rain','Rainbow','Restaurant','Ribbon','Rice',
    'River','Rocket','Roof','Rope','Sailor','Salt','Sandwich','Scarf',
    'School','Shark','Sheep','Ship','Shirt','Shoe','Shovel','Sister',
    'Snail','Snake','Snow','Soccer','Sock','Soldier','Song','Soup',
    'Spider','Spoon','Spring','Squirrel','Stadium','Star','Storm','Strawberry',
    'Sugar','Summer','Sun','Sweater','Swimming','Table','Taxi','Tea',
    'Teacher','Teapot','Television','Tennis','Thunder','Tiger','Tomato','Tooth',
    'Towel','Tractor','Train','Trophy','Truck','Trumpet','Tunnel','Turtle',
    'Twin','Valley','Village','Violin','Volcano','Waffle','Wagon','Wall',
    'Watch','Wedding','Whale','Wife','Wind','Window','Winter','Wolf',
    'Wrench','Zebra'
  ];
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_signed_in');
  end if;

  select host_id, status into v_host, v_status
    from public.games where id = p_game;

  if v_host is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;
  if v_host <> v_uid then
    return jsonb_build_object('ok', false, 'reason', 'not_host');
  end if;
  if v_status <> 'in_progress' then
    return jsonb_build_object('ok', false, 'reason', 'not_started');
  end if;

  if exists (select 1 from public.game_state where game_id = p_game) then
    return jsonb_build_object('ok', true, 'already', true);
  end if;

  v_total := v_wph * 2;

  for v_word in
    select w
    from unnest(v_bank) as w
    order by md5(w || p_game::text)
    limit v_total
  loop
    insert into public.game_words (game_id, word_index, word)
    values (p_game, i, v_word);
    i := i + 1;
  end loop;

  if i < v_total then
    return jsonb_build_object('ok', false, 'reason', 'deal_failed');
  end if;

  v_team := public.mw_starting_team(0);
  insert into public.game_state
    (game_id, phase, word_index, cluing_team, step, words_per_half, host_line)
  values
    (p_game, 'first_half', 0, v_team, 'awaiting_clue', v_wph,
     public.mw_clue_prompt(p_game, v_team, 'first_half'));

  return jsonb_build_object('ok', true);
end;
$$;
