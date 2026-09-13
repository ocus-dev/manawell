class_name CampaignDefinitions
extends RefCounted

const ACTS: Array[Dictionary] = [
	{
		"id": "act_01",
		"display_name": "Broken Foundry",
		"layout_revision": "A_valley-landmarks-02",
		"nodes": [
			{"id": "act_01_node_01", "display_name": "Scrap Approach", "type": "monster", "position": [0.10, 0.79], "prerequisites": [], "encounter_key": "act_01.monster_01"},
			{"id": "act_01_node_02", "display_name": "Intake Well", "type": "well", "position": [0.12, 0.64], "prerequisites": ["act_01_node_01"], "encounter_key": "act_01.well_02", "well_id": "well_1"},
			{"id": "act_01_node_03", "display_name": "Broken Viaduct", "type": "monster", "position": [0.32, 0.46], "prerequisites": ["act_01_node_02"], "encounter_key": "act_01.monster_03"},
			{"id": "act_01_node_04", "display_name": "Cinder Crossing", "type": "monster", "position": [0.37, 0.30], "prerequisites": ["act_01_node_03"], "encounter_key": "act_01.monster_04"},
			{"id": "act_01_node_05", "display_name": "Pressure Well", "type": "well", "position": [0.49, 0.51], "prerequisites": ["act_01_node_04"], "encounter_key": "act_01.well_05", "well_id": "well_2"},
			{"id": "act_01_node_06", "display_name": "Rail Graveyard", "type": "monster", "position": [0.58, 0.69], "prerequisites": ["act_01_node_05"], "encounter_key": "act_01.monster_06"},
			{"id": "act_01_node_07", "display_name": "Furnace Rampart", "type": "monster", "position": [0.74, 0.56], "prerequisites": ["act_01_node_06"], "encounter_key": "act_01.monster_07"},
			{"id": "act_01_node_08", "display_name": "Crown Well", "type": "well", "position": [0.68, 0.36], "prerequisites": ["act_01_node_07"], "encounter_key": "act_01.well_08", "well_id": "well_3"},
			{"id": "act_01_node_09", "display_name": "The Crown Furnace", "type": "boss", "position": [0.74, 0.18], "prerequisites": ["act_01_node_01", "act_01_node_02", "act_01_node_03", "act_01_node_04", "act_01_node_05", "act_01_node_06", "act_01_node_07", "act_01_node_08"], "encounter_key": "act_01.boss_09"},
		],
	},
]
