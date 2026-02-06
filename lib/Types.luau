--!strict

export type ShapeType = 'Block' | 'Ball' | 'Cylinder' | 'Wedge' | 'CornerWedge'

export type BoundingVolume = {
	Position: Vector3,
	CFrame: CFrame,
	HalfSize: Vector3,
	Shape: ShapeType,

	-- sphere specific
	radius: number?,

	-- cylinder specific
	start: Vector3?,
	axis: Vector3?,
	axisLength: number?,
	radiusSquared: number?,
}

export type Node = {
	left: Node?,
	right: Node?,
	min: Vector3,
	max: Vector3,
	id: number, -- -1 for internal nodes
}

export type TrackableTable = {
	Position: Vector3?,
	WorldPosition: Vector3?,
	CFrame: CFrame?,
	GetPivot: ((self: any) -> CFrame)?,
	[any]: any,
}

export type Trackable = BasePart | Model | Camera | Attachment | Bone | TrackableTable

export type UID = number

export type TrackableData = {
	activeGroupMemberships: { [UID]: number },
	memberOfGroups: { [UID]: boolean },
	lastPosition: Vector3,
	strategy: number,
	isDirty: boolean,
}

export type Zone = {
	BindToGroups: (zone: Zone, ...Group) -> Zone,
	UnbindFromGroups: (zone: Zone, ...Group) -> Zone,
	GetGroups: (zone: Zone) -> { Group },
	Destroy: (zone: Zone) -> (),
	index: number,
	part: BasePart?,
}

export type Callback = (Trackable, Zone, any?) -> ()

export type Group = {
	SetPriority: (self: Group, priority: number) -> Group,
	TrackItem: (self: Group, trackable: Trackable, customData: any?) -> Group,
	UntrackItem: (self: Group, trackable: Trackable) -> Group,
	OnEntered: (self: Group, callback: Callback) -> () -> (),
	OnExited: (self: Group, callback: Callback) -> () -> (),
	IsItemInside: (self: Group, trackable: Trackable) -> boolean,
	IsPointInside: (self: Group, position: Vector3) -> boolean,
	IsItemTracked: (self: Group, trackable: Trackable) -> boolean,
	GetTrackedItems: (self: Group) -> { Trackable },
	GetItemsInside: (self: Group) -> { Trackable },
	GetZones: (self: Group) -> { Zone },
	Destroy: (self: Group) -> (),
	UID: UID,
}

return nil
