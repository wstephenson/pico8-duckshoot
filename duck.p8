pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
------------
-- pico-ec - 
-- a small scene/entity/component
-- library built for the fantasy
-- console, pico-8.
-- @script pico-ec
-- @author joeb rogers
-- @license mit
-- @copyright joeb rogers 2018

--- a table storing various utility
-- functions used by the ecs.
utilities = {}

--- assigns the contents of a table to another.
-- copy over the keys and values from source 
-- tables to a target. assign only shallow copies
-- to the target table. for a deep copy, use
-- deepassign instead.
-- @param target the table to be copied to.
-- @param source either a table to copy from,
-- or an array storing multiple source tables.
-- @param multiple specifies whether source contains
-- more than one table.
-- @return the target table with overwritten and 
-- appended values.
function utilities.assign(target, source, multiple)
  multiple = multiple or false
  if multiple == true then
    for count = 1, #source do
      target = utilities.assign(target, source[count])
    end
    return target
  else
    for k, v in pairs(source) do
      target[k] = v;
    end
  end
  return target;
end

--- deep assigns the contents of a table to another.
-- copy over the keys and values from source 
-- tables to a target. will recurse through child
-- tables to copy over their keys/values as well.
-- @param target the table to be copied to.
-- @param source either a table to copy from,
-- or an array storing multiple source tables.
-- @param multiplesource specifies whether source
-- contains more than one table.
-- @param exclude either a string or an array of
-- string containing keys to exclude from copying.
-- @param multipleexclude specifies whether exclude
-- contains more than one string.
-- @return the target table with overwritten and 
-- appended values.
function utilities.deepassign(target, source, multiplesource, exclude, multipleexclude)
    multiplesource = multiplesource or false
    exclude = exclude or nil
    multipleexclude = multipleexclude or false

    if multiplesource then
        for count = 1, #source do
            target = utilities.deepassign(target, source[count], false, exclude, multipleexclude)
        end
        return target
    else
        for k, v in pairs(source) do
            local match = false
            if multipleexclude then
                for count = 1, #exclude do
                    if (k == exclude[count]) match = true
                end
            elseif exclude then
                if (k == exclude) match = true
            end
            if not match then
                if type(v) == "table" then
                    target[k] = utilities.deepassign({}, v, false, exclude, multipleexclude)
                else
                    target[k] = v;
                end
            end
        end
    end
    return target;
end

--- removes a string key from a table.
-- @param t the table to modify.
-- @param k the key to remove.
function utilities.tableremovekey(t, k)
    t[k] = nil
end

--- unloads a scene, and loads in the specified new one.
-- @param currentscene the currently running scene.
-- @param newscene the new scene to load in.
-- @return the newly loaded in scene.
function utilities.changescene(currentscene, newscene)
    currentscene:unload()
    currentscene = newscene
    currentscene:onload()
    return currentscene
end

--- a table used as the base for a 
-- reusable gameobject.
-- @field active whether the current object 
-- should be processed. if disabled, this 
-- object won't be updated or drawn.
-- @field flagremoval whether the current
-- object should be flagged for removal.
-- if set to true, the object will be 
-- cleaned up once it's parent has finished
-- processing.
_baseobject = {    
    active      = true,
    flagremoval = false
}

--- sets an object's 'active' field.
-- @param state a bool representing what
-- the field be set to.
function _baseobject:setactive(state)
    self.active = state
end

--- sets an object's 'flagremoval' field.
-- @param state a bool representing what
-- the field be set to.
function _baseobject:setremoval(state)
    self.flagremoval = state
end

--- the number of entities currently 
-- created within the application 
-- lifetime.
entity_count = 0

--- a table used as a base for entities.
-- this table is also assigned the 
-- properties of _baseobject.
-- this table can be combined with a 
-- custom entity object with overwritten
-- fields and functions when the
-- createentity() function is called.
-- @field _components a table containing 
-- the entity's added components.
-- @field _componentsindexed a table 
-- containing the entity's added 
-- components, indexed in the order
-- they were added to the entity.
-- @field type a string containing the 
-- object's "type".
-- @field name a string containing the 
-- entity's name. used for indexing within
-- the scene. 
-- @field ind the index of this entity's
-- position within the scene's ordererd
-- array.
_entity = {
    _components        = {},
    _componentsindexed = {},
    type               = "entity",
    name               = "entity_"..entity_count,
    ind                = 0
}

-- append the properties of _baseobject to _entity.
utilities.deepassign(_entity, _baseobject)

--- add a component to the entity's list of components.
-- the added component has it's parent assiged to the 
-- entity.
-- @param component the component to add.
-- @return returns early if the component
-- isn't valid.
function _entity:addcomponent(component)
    if not component or not component.type or component.type != "component" then return end

    self._components[component.name] = component
    add(self._componentsindexed, component)
    component.ind = #self._componentsindexed
    self._components[component.name]:setparent(self)
    self._components[component.name]:onaddedtoentity()
end

--- removes a component from the entity's list of components.
-- the specified component is flagged for removal and 
-- will be removed once the other component's have 
-- finished processing.
-- @param name the string index of the component
-- to remove.
function _entity:removecomponent(name)
    self._components[name]:setremoval(true)
end

--- returns a component specified by name.
-- @param name the string index of the component
-- to retrieve.
-- @return the retrieved component.
function _entity:getcomponent(name)
    return self._components[name]
end

--- called when the entity is added to a
-- scene with the addentity() function.
-- has no default behaviour, should be 
-- overwritten by a custom entity.
function _entity:onaddedtoscene() end

--- calls init() on all of an entity's components.
function _entity:init()
    for v in all(self._componentsindexed) do
        v:init()
    end
end

--- calls update() on all of an entity's components.
-- loops back around once all components have been 
-- updated to remove any components that have been
-- flagged.
-- @return will return early if the entity isn't
-- active.
-- @return will return before resetting indexes
-- if no objects have been removed.
function _entity:update()
    if not self.active then return end

    local reindex = false

    for v in all(self._componentsindexed) do
        if v.active then
            v:update()
        end
    end

    for v in all(self._componentsindexed) do
        if v.flagremoval then
            utilities.tableremovekey(self._components, v.name)
            del(self._componentsindexed, v)
        end
    end

    if (not reindex) return

    local i = 1
    for v in all(self._componentsindexed) do
        v.ind = i
        i += 1
    end
end

--- calls draw() on all of an entity's components.
-- @return will return early if the entity isn't
-- active.
function _entity:draw()
    if not self.active then return end
    for v in all(self._componentsindexed) do
        if v.active then
            v:draw()
        end
    end
end

--- the number of components currently 
-- created within the application 
-- lifetime.
component_count = 0

--- a table used as a base for components.
-- this table is also assigned the 
-- properties of _baseobject.
-- this table can be combined with a 
-- custom component object with overwritten
-- fields and functions when the
-- createcomponent() function is called.
-- this is the intended method for creating
-- custom behaviours.
-- @field parent a reference to the entity
-- that contains this component.
-- @field type a string containing the 
-- object's "type".
-- @field name a string containing the 
-- component's name. used for indexing 
-- within the parent entity. 
-- @field ind the index of this component's
-- position within the entity's ordererd
-- array.
_component = {
    parent = nil,
    type   = "component",
    name   = "component_"..component_count,
    ind    = 0
}

-- append the properties of _baseobject to _component.
utilities.deepassign(_component, _baseobject)

--- called when the component is added to
-- an entity with the addcomponent() function.
-- has no default behaviour, should be 
-- overwritten by a custom component.
function _component:onaddedtoentity() end

--- a function to initialise the component.
-- init is a placeholder that can be overwritten
-- upon creation of a component. will be called
-- once when the application calls _init() and
-- when a new scene's onload() function is
-- called.
function _component:init() end

--- a function to update the component.
-- update is a placeholder that can be overwritten
-- upon creation of a component. will be called
-- every frame when the application calls _update().
function _component:update() end

--- a function to draw the component.
-- draw is a placeholder that can be overwritten
-- upon creation of a component. will be called
-- every frame when the application calls _draw().
function _component:draw() end

--- sets a reference to the component's parent
-- entity.
-- @param parent the entity containing this 
-- component.
function _component:setparent(parent)
    self.parent = parent
end

--- a table used as a base for scenes.
-- this table can be combined with a 
-- custom scene object with overwritten
-- fields and functions when the
-- createscene() function is called.
-- @field _entities a list of all the
-- entities currently added to this
-- scene.
-- @field _entitiesindexed a table 
-- containing the scenes's added 
-- entities, indexed in the order
-- they were added to the scene.
-- @field type a string containing the 
-- object's "type".
_scene = {
    _entities        = {},
    _entitiesindexed = {},
    type             ="scene"
}

--- adds an entity to this scene's entity list.
-- @param entity the entity to add.
-- @return will return early if the entity is
-- invalid.
function _scene:addentity(entity)
    if not entity or not entity.type or entity.type != "entity" then return end

    self._entities[entity.name] = entity
    add(self._entitiesindexed, entity)
    entity.ind = #self._entitiesindexed
    self._entities[entity.name]:onaddedtoscene()
end

--- flags an entity for removal from the scene.
-- @param name the name the entity is indexed
-- by within the scene.
function _scene:removeentity(name)
    self._entities[name]:setremoval(true)
end

--- returns the entity within the scene with
-- the passed in name.
-- @param name the name the entity is indexed
-- by within the scene.
-- @return the retrieved entity.
function _scene:getentity(name)
    return self._entities[name]
end

--- calls init() on all of the scene's entities.
function _scene:init()
    for v in all(self._entitiesindexed) do
        v:init()
    end
end

--- calls update() on all of an scene's entities.
-- entity is skipped if not active.
-- loops back around once all entities have been 
-- updated to remove any entities that have been
-- flagged.
-- @return will return before resetting indexes
-- if no objects have been removed.
function _scene:update()
    local reindex = false

    for v in all(self._entitiesindexed) do
        if v.active then
            v:update()
        end
    end

    for v in all(self._entitiesindexed) do
        if v.flagremoval then
            utilities.tableremovekey(self._entities, v.name)
            del(self._entitiesindexed, v)
            reindex = true
        end
    end

    if (not reindex) return

    local i = 1
    for v in all(self._entitiesindexed) do
        v.ind = i
        i += 1
    end
end

--- calls draw() on all of an scene's entities.
-- entity is skipped if not active.
function _scene:draw()
    for v in all(self._entitiesindexed) do
        if v.active then
            v:draw()
        end
    end
end

--- function called when the scene is loaded
-- in as the active scene.
-- by default calls init() on all of it's 
-- stored entities. if planning to overwrite
-- the onload() function with a custom scene,
-- this behvaiour should be copied over to
-- the new scene, else no entities or 
-- components will be initialised unless the
-- scene is the loaded in the application 
-- _init().
function _scene:onload()
    for k, v in pairs(self._entities) do
        self._entities[k]:init()
    end
end

--- function called during the change to a
-- new scene. to be overwritten if any 
-- custom behaviours need special 
-- attention before being removed.
function _scene:unload() end

--- a table storing various factory
-- functions used by the ecs.
factory = {}

--- creates and returns a new scene object.
-- will either return a new default scene or
-- one combined with a passed in custom scene.
-- @param scene a custom scene to combine with
-- the default scene.
-- @return the created scene object.
function factory.createscene(scene)
    local sc = scene or {}
    sc = utilities.deepassign({}, {_scene, sc}, true)
    return sc
end

--- creates and returns a new entity object.
-- will either return a new default entity or
-- one combined with a passed in custom entity.
-- also increments the global entity count.
-- @param entity a custom entity to combine with
-- the default entity.
-- @return the created entity object.
function factory.createentity(entity)
    local ent = entity or {}
    ent = utilities.deepassign({}, {_entity, ent}, true)
    entity_count += 1
    return ent
end

--- creates and returns a new component object.
-- will either return a new default component or
-- one combined with a passed in custom component.
-- also increments the global component count.
-- @param component a custom component to combine 
-- with the default component.
-- @return the created component object.
function factory.createcomponent(component)
    local c = component or {}
    c = utilities.deepassign({}, {_component, c}, true)
    component_count += 1
    return c
end


-->8
-- transform
_transformcomponent = {
  name = "transform",
  x = 0,
  y = 0
}

-- rect
_rectcomponent = {
  name = "rect",
  transform = nil,
  w = 0,
  h = 0,
  color = 0
}

function _rectcomponent:setcolor(col)
  self.color = col
end

function _rectcomponent:setsize(w, h)
  self.w = w or 0
  self.h = h or 0
end

function _rectcomponent:init()
 self.transform = self.parent:getcomponent("transform")
end

function _rectcomponent:draw()
 local x = self.transform.x
 local y = self.transform.y
 local w = x + self.w
 local h = y + self.h
 rectfill(x, y, w, h, self.color)
end

-- sprite
_sprcomponent = {
  name = "spr",
  transform = nil,
  index = 0,
}

function _sprcomponent:setindex(i)
	self.index=i
end

function _sprcomponent:init()
 self.transform = self.parent:getcomponent("transform")
end

function _sprcomponent:draw()
 local x = self.transform.x
 local y = self.transform.y
 spr(self.index,x,y)
end

-- mover
_movercomponent = {
  name = "mover",
  transform = nil
}

function _movercomponent:init()
  self.transform = self.parent:getcomponent("transform")
end

function _movercomponent:update()
  if (btn(0)) self.transform.x -= 1
  if (btn(1)) self.transform.x += 1
  if (btn(2)) self.transform.y -= 1
  if (btn(3)) self.transform.y += 1
end

-- duckmover
_duckmovercomponent = {
 name = "duckmover",
 transform = nil,
 xv = 1,
 yv = 0
}
		
function _duckmovercomponent:init()
  self.transform = self.parent:getcomponent("transform")
end

function _duckmovercomponent:update()
 self.transform.x += self.xv
 if self.transform.x > 127 then self.transform.x = 0 end
 self.transform.y += self.yv
 if self.transform.y > 127 then self.transform.y = 0 end
end

function _duckmovercomponent:setspeed(xv,yv)
 self.xv = xv
 self.yv = yv
end

-- timer
_timercomponent = {
 name = "timer"
 t = 0
}

function _timercomponent:update()
 self.t++
end

-- duckspawner 
_duckspawnercomponent = {
 name = "duckspawner",
 transform = nil,
 timer = nil,
}

function _duckspawnercomponent:init()
 self.transform = self.parent:getcomponent("transform")
 self.timer = self.parent:getcomponent("timer")
end

function _duckspawnercomponent:update()
 if self.timer.t % 10 then
 local duckent = factory.createentity()
 -- update duck
 duckent:addcomponent(factory.createcomponent(_transformcomponent))
 duckent:addcomponent(factory.createcomponent(_sprcomponent))
 duckent:addcomponent(factory.createcomponent(_duckmovercomponent))
 duckent:getcomponent("duckmover"):setspeed(1,0)
 duckent:getcomponent("spr"):setindex(0)
 -- how do we get the scene to add the duck to it?

end
-->8
-- main

-- create scenes and entities
local movingrectscene = factory.createscene()
local backgroundent = factory.createentity()
local playerent = factory.createentity()
local timer = factory.createentity()

timer:addcomponent(factory.createcomponent(_timercomponent))
-- create components for background rect
backgroundent:addcomponent(factory.createcomponent(_transformcomponent))
backgroundent:addcomponent(factory.createcomponent(_rectcomponent))
--let's set the background's size
backgroundent:getcomponent("rect"):setsize(128, 128)
--let's change the color of the background
backgroundent:getcomponent("rect"):setcolor(5)

-- create components for player rect
playerent:addcomponent(factory.createcomponent(_transformcomponent))
playerent:addcomponent(factory.createcomponent(_sprcomponent))
playerent:addcomponent(factory.createcomponent(_movercomponent))
--let's change the color of the player
playerent:getcomponent("spr"):setindex(1)

--
mainscene = movingrectscene
mainscene:addentity(backgroundent)
mainscene:addentity(playerent)
mainscene:addentity(duckent)

function _init()
  mainscene:init()
end

function _update()
  mainscene:update()
end

function _draw()
 mainscene:draw()
end
__gfx__
00000000aaa0aaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000a00000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700a00000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000a00000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700a00000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaa0aaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
