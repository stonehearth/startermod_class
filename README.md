# startermod_class
A basic class mod to get you going!

Instructions for use: Download the mod. Unzip to your stonehearth mods directory, as a peer to `stonehearth.smod` and `radiant.smod`. Make sure the folder is named `startermod_class`, not startermod_class-master. 

Before digging into the mod files, if this is your first time modding, you may want to checkout [startermod_basic](https://github.com/stonehearth/startermod_basic) 

Inside the `startermod_class` folder, you should see a `manifest.json` file, and this folder structure:
```
├───ai
│   ├───actions
│   │   └───combat
│   └───packs
├───data
│   └───monster_tuning
│       └───undead
├───jobs
│   └───necromancer
│       ├───images
│       ├───necromancer_abilities
│       ├───necromancer_outfit
│       └───necronomicon
├───locales
└───recipes
```

This structure is similar to the structure inside `stonehearth.smod`. The files are referred to in the mod itself by aliases which are defined in `manifest.json` along with mixintos and other meta data.

For example, the necromancer class talisman is referred to as `necromancer:talisman` which is defined in the mainfest as:
`"necromancer:talisman": "file(jobs/necromancer/necronomicon/necronomicon_talisman.json)",`

The new necromancer class is added to the game by mixing `jobs/index.json` file into Stonehearth's `jobs/index.json` file. In the manifest that looks like this:
```
"mixintos" : {
      "stonehearth/jobs/herbalist/recipes/recipes.json" : "file(recipes/recipes.json)",
      "stonehearth/jobs/index.json" : "file(jobs/index.json)"
   },
 ```
The jobs index mixin adds `startermod_class:jobs:necromancer` to the list of jobs in Stonehearth, and the description alias `startermod_class:jobs:necromancer` maps to `jobs/necromancer/necromancer_description.json` - which is the starting place for the class and holds the basic information like `parent_job` and points to the other resources via aliases.

The herbalist recipe mixinto above adds the Necronomicon recipie to the Herbalist workshop. With that, the necromancer class is hooked into the game.
