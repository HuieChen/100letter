class_name StageLayout
extends RefCounted
## Full original textures are positioned from measured alpha bounds, never cropped.
const CANVAS := Vector2(1600,900)
const ART_BOUNDS = {
	"post_office":[Vector2(1811,1280),Rect2(360,67,1064,1150)],
	"community_center":[Vector2(1811,1280),Rect2(216,16,1477,1232)],
	"bus_stop":[Vector2(1920,1080),Rect2(447,501,835,419)],
	"lookout":[Vector2(1920,1080),Rect2(25,318,1876,536)],
	"residential":[Vector2(3508,2480),Rect2(247,394,2677,1947)],
	"chess_stall":[Vector2(1920,1080),Rect2(68,13,1423,1014)],
	"tarot_shop":[Vector2(1920,1080),Rect2(153,185,1326,652)]
}

static func plan(location_id: String) -> Dictionary:
	var target := Vector2(574,105)
	var height: float = 625.0
	var feet: Dictionary = {}
	var heights: Dictionary = {}
	var walk := Rect2(175,703,1270,101)
	var spawn := Vector2(252,780)
	var entrance := Vector2(696,739)
	var zone: String = "post_courtyard"
	match location_id:
		"community_center":
			# Keep the full original texture visible while making the entrance and
			# windows legible at a human scale beside the courier.
			target=Vector2(385,20); height=750
			feet={"chenyuan":Vector2(385,745)}; heights={"chenyuan":126.0}
			entrance=Vector2(991,751); zone="civic_square"
		"bus_stop":
			target=Vector2(652,374); height=330
			feet={"chenyuan":Vector2(1021,735)}; heights={"chenyuan":126.0}
			walk=Rect2(184,709,1254,103); spawn=Vector2(251,777)
			entrance=Vector2(860,724); zone="coastal_road"
		"lookout":
			target=Vector2(122,295); height=390
			feet={"june_arlen":Vector2(530,677),"mira_vale":Vector2(1030,683),"nora_vale":Vector2(1390,671)}
			heights={"june_arlen":127.0,"mira_vale":128.0,"nora_vale":127.0}
			walk=Rect2(140,663,1304,122); spawn=Vector2(229,753)
			entrance=Vector2(466,691); zone="high_cliff"
		"residential":
			target=Vector2(485,118); height=610
			walk=Rect2(175,738,1270,66)
			feet={"june_arlen":Vector2(1210,761)}; heights={"june_arlen":128.0}
			entrance=Vector2(698,742); zone="rose_courtyard"
		"chess_stall":
			target=Vector2(614,176); height=505
			entrance=Vector2(987,720); zone="plane_tree_square"
		"tarot_shop":
			target=Vector2(509,233); height=456
			entrance=Vector2(986,712); zone="tower_terrace"
	var id: String = location_id if ART_BOUNDS.has(location_id) else "post_office"
	var dimensions: Vector2 = ART_BOUNDS[id][0]
	var alpha: Rect2 = ART_BOUNDS[id][1]
	var scale_value: float = height/alpha.size.y
	return {"location_id":id,"building":Rect2(target-alpha.position*scale_value,dimensions*scale_value),
		"visible_building":Rect2(target,alpha.size*scale_value),"npc_feet":feet,"npc_heights":heights,
		"walk_bounds":walk,"spawn":spawn,"arrival":spawn,"exit":Vector2(160,779),
		"entrance":entrance,"palette_zone":zone,"actor_height":126.0,"ground_hit":Rect2(130,650,1330,169)}
