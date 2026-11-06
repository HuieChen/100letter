extends RefCounted
## The user's location assignments. Positions are in the current street's world space.
const RESIDENTS = {
	"chef":{"family":"community","foot":Vector2(12260,840),"height":350.0,"zh":"餐车老板","en":"Chef"},
	"community":{"family":"community","foot":Vector2(3450,850),"height":290.0,"zh":"社区工作人员","en":"Community staff"},
	"grocer":{"family":"community","foot":Vector2(6660,850),"height":300.0,"zh":"杂货店店主","en":"Grocer"},
	"resident":{"family":"residential","foot":Vector2(3450,850),"height":310.0,"zh":"居民","en":"Resident"},
	"lookout":{"family":"residential","foot":Vector2(6750,850),"height":310.0,"zh":"观景台访客","en":"Visitor"},
	"bookseller":{"family":"postal","foot":Vector2(5890,850),"height":310.0,"zh":"书店店主","en":"Bookseller"},
	"guitarist":{"family":"coastal","foot":Vector2(3370,850),"height":310.0,"zh":"吉他手","en":"Guitarist"},
	"record_clerk":{"family":"coastal","foot":Vector2(3730,850),"height":310.0,"zh":"唱片店店员","en":"Record store clerk"}
}
