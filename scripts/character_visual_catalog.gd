class_name CharacterVisualCatalog
extends RefCounted

const BODY_SCENE := "res://assets/characters/rigged/source/universal-base-characters/Base Characters/Superhero_Male_FullBody.gltf"

const FIGHTERS := {
	"bennet": {
		"body_scene": "res://assets/characters/rigged/custom/bennet/bennet-krav-maga.glb",
		"skeleton_path": "Armature/Skeleton3D",
		"palette": {"primary": Color("183b59"), "secondary": Color("25cbd3"), "skin": Color("d8a47f")},
		"outfit": "krav_maga_combat_uniform",
		"accessories": [],
		"prebuilt_outfit": true,
		"prebuilt_accessories": false,
	},
	"avigdor": {
		"body_scene": BODY_SCENE,
		"skeleton_path": "Armature/Skeleton3D",
		"palette": {"primary": Color("18191f"), "secondary": Color("781f31"), "skin": Color("c99171")},
		"outfit": "charcoal_underworld_coat",
		"accessories": ["gray_hair", "gray_beard"],
	},
	"bibi": {
		"body_scene": BODY_SCENE,
		"skeleton_path": "Armature/Skeleton3D",
		"palette": {"primary": Color("102f5a"), "secondary": Color("d5aa45"), "skin": Color("e0aa82")},
		"outfit": "prime_navy_suit",
		"accessories": ["silver_hair", "lapel_pin"],
	},
	"yair_golan": {
		"body_scene": BODY_SCENE,
		"skeleton_path": "Armature/Skeleton3D",
		"palette": {"primary": Color("4c5836"), "secondary": Color("a9b18c"), "skin": Color("d5a17c")},
		"outfit": "olive_field_uniform",
		"accessories": ["gray_buzz", "stubble", "sunglasses"],
	},
}

static func definition(fighter_id: String) -> Dictionary:
	return FIGHTERS.get(fighter_id, {}).duplicate(true)
