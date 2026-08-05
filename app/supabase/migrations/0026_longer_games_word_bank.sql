-- =============================================================================
-- 0026_longer_games_word_bank.sql
-- =============================================================================
-- Longer senior-paced matches (~20–25 min): 8 words per half, and a ~3× larger
-- deal bank so secrets rarely repeat across sessions.

alter table public.game_state
  alter column words_per_half set default 8;

comment on column public.game_state.words_per_half is
  'Secret words per half (8 ≈ 20–25 min full game; total words = 2 × this).';

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
    'Kitchen','Garden','Window','Blanket','Teapot','Pillow','Candle','Mirror',
    'Clock','Kettle','Slipper','Umbrella','Doorbell','Bookshelf','Armchair',
    'Cupboard','Fireplace','Staircase','Mailbox','Doorway',
    'Apple','Butter','Cookie','Coffee','Honey','Lemon','Pancake','Popcorn',
    'Pumpkin','Sandwich','Banana','Cupcake','Oatmeal','Pretzel','Waffle',
    'Yogurt','Biscuit','Caramel','Cherry','Noodle',
    'Sunshine','Rainbow','Mountain','River','Flower','Meadow','Snowman',
    'Seashell','Thunder','Breeze','Raindrop','Forest','Valley','Ocean',
    'Sunset','Cloud','Pebble','Willow','Daisy','Icicle',
    'Puppy','Kitten','Rabbit','Robin','Butterfly','Squirrel','Ladybug',
    'Penguin','Dolphin','Turtle','Goldfish','Hamster','Sparrow','Pony',
    'Lamb','Duckling','Seagull','Owl','Frog','Chipmunk',
    'Grandma','Postcard','Bicycle','Picnic','Quilt','Puzzle','Melody',
    'Birthday','Holiday','Grandpa','Neighbor','Teacher','Library','Concert',
    'Painting','Dancing','Singing','Knitting','Gardening','Storytime',
    'Bakery','Market','School','Station','Bridge','Sidewalk','Farmhouse',
    'Lighthouse','Harbor','Suitcase','Ticket','Airplane','Train','Taxi',
    'Campfire','Trail','Cabin','Highway','Ferry','Map',
    'Sweater','Scarf','Jacket','Button','Pocket','Glasses','Bracelet',
    'Necklace','Handbag','Wallet','Camera','Notebook','Pencil','Envelope',
    'Stamp','Basket','Lantern','Hammer','Needle','Ribbon',
    'Autumn','Winter','Springtime','Firework','Parade','Carnival',
    'Wedding','Anniversary','Invitation','Present','Balloon','Confetti',
    'Cocoa','Toast','Soup','Salad','Muffin','Jam','Gravy','Pie'
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
