local game_master_lib = require 'stonehearth.lib.game_master.game_master_lib'
local Entity = _radiant.om.Entity
local Point3 = _radiant.csg.Point3
local log = radiant.log.create_logger('combat')

local RaiseDead = class()

RaiseDead.name = 'attack ranged'
RaiseDead.does = 'stonehearth:combat:attack_ranged'
RaiseDead.args = {
   target = Entity
}
RaiseDead.version = 2
RaiseDead.priority = 10
RaiseDead.weight = 1

function RaiseDead:start_thinking(ai, entity, args)
   -- refetch every start_thinking as the set of actions may have changed
   self._attack_types = stonehearth.combat:get_combat_actions(entity, 'stonehearth:combat:ranged_attacks')

   self:_choose_attack_action(ai, entity, args)
end

function RaiseDead:_choose_attack_action(ai, entity, args)
   self._attack_info = stonehearth.combat:choose_attack_action(entity, self._attack_types)

   if self._attack_info then
      ai:set_think_output()
      return
   end

   -- choose_attack_action might have complex logic, so just wait 1 second and try again
   -- instead of trying to guess which coolodowns to track
   self._think_timer = stonehearth.combat:set_timer("RaiseDead waiting for cooldown", 1000, function()
         self._think_timer = nil
         self:_choose_attack_action(ai, entity, args)
      end)
end

function RaiseDead:stop_thinking(ai, entity, args)
   if self._think_timer then
      self._think_timer:destroy()
      self._think_timer = nil
   end

   self._attack_types = nil
end

function RaiseDead:run(ai, entity, args)
   local target = args.target

   -- Set the status text for the action.
   ai:set_status_text_key('startermod_class:ai.actions.status_text.raise_dead', { target = target })

   -- Abort if hearthling is standing on a ladder.
   if radiant.entities.is_standing_on_ladder(entity) then
      -- We generally want to prohibit combat on ladders. This case is particularly unfair,
      -- because the ranged unit can attack, but melee units can't find an adjacent to retaliate.
      ai:abort('Cannot attack attack while standing on ladder')
   end

   -- Abort if hearthling can't see the enemy.
   if not stonehearth.combat:has_line_of_sight(entity, args.target) then
      ai:abort('Target not in sight')
      return
   end

   -- Look at target enemy.
   radiant.entities.turn_to_face(entity, target)

   -- Start a cooldown.
   stonehearth.combat:start_cooldown(entity, self._attack_info)

   -- the target might die when we attack them, so unprotect now!
   ai:unprotect_argument(target)

   -- this is a timer so the skeleton is not raised right at the first frame of the animation
   self._raise_timers = {}
   self:_add_raise_timer(entity, target, self._attack_info.active_frame * 33.3) --1 frame is ~33.3ms (or 1000/33)

   -- Show some particles effects.
   radiant.effects.run_effect(entity, "stonehearth:effects:buff_tonic_stamina_added")
   -- Play the animation found in the json.
   ai:execute('stonehearth:run_effect', { effect = self._attack_info.effect })
end

function RaiseDead:_add_raise_timer(entity, target, time_to_raise)
   local raise_timer = stonehearth.combat:set_timer("RaiseDead raise", time_to_raise, function()
      -- Raise the dead!
      self:raise_dead(entity)
   end)
   table.insert(self._raise_timers, raise_timer)
end

function RaiseDead:stop(ai, entity, args)
   if self._raise_timers then
      for _, timer in ipairs(self._raise_timers) do
         timer:destroy()
      end
      self._raise_timers = nil
   end

   self._attack_info = nil
end

function RaiseDead:raise_dead(entity)
   -- Get information about the hearthling doing this action.
   local entity_location = radiant.entities.get_world_location(entity)
   local player_id = radiant.entities.get_player_id(entity)

   -- Pick a location to spawn a skeleton around the hearthling.
   local x, z = entity_location.x, entity_location.z
   local dir = radiant.math.random_xz_unit_vector()
   dir:scale(5)

   local spawn_location = radiant.terrain.get_point_on_terrain(Point3(dir.x + x, 1, dir.z + z))

   -- Information about the monster we want to spawn.
   local skeleton_info = {
      --this tuning file is exactly the same as the 'insane_undead' tuning
      --except this one does not have loot, avoiding dropping those items
      tuning = 'startermod_class:monster_tuning:undead:necromancer_undead',
      from_population = {
         location = Point3(0,0,0),
         role = 'skeleton'
      }
   }

   -- Get the population for skeletons.
   local undead_population = stonehearth.population:get_population('undead')

   -- Spawn a skeleton at the spawn_location.
   local spawned_monsters = game_master_lib.create_citizens(undead_population, skeleton_info, spawn_location)

   -- We only spawn one monster, grab it.
   local skeleton = spawned_monsters[1]

   -- Switch the player_id of the spawned skeleton to be the same as
   -- the player_id of the heathling who spawned it.
   radiant.entities.set_player_id(skeleton, player_id)

   --a cool summon effect in the skeleton
   radiant.effects.run_effect(skeleton, "stonehearth:effects:death")

   -- Set a timer to despawn the skeleton after a time to avoid filling the world with skeletons.
   stonehearth.calendar:set_timer('skeleton despawn', 1000, function()
      if skeleton and skeleton:is_valid() then
         self:remove_items_from_skeleton(skeleton)
         --0 health to kill it
         radiant.entities.set_health(skeleton, 0)
      end
   end)
end

function RaiseDead:remove_items_from_skeleton(skeleton)
   --this is necessary as even though they had their loot removed from the tuning file,
   --they would still drop the item in their hands
   local equipment_component = skeleton:get_component('stonehearth:equipment')
   local items = equipment_component:get_all_items()
   for key, item in pairs(items) do
      equipment_component:unequip_item(item)
   end
end

return RaiseDead