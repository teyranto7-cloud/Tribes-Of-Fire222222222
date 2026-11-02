extends Node3D
## Real bones and attachments driven by the existing procedural pose controllers.
var skeleton: Skeleton3D
var controls: Array[Node3D] = []
var attachments: Array[BoneAttachment3D] = []
func setup(player) -> void:
	skeleton = Skeleton3D.new()
	add_child(skeleton)
	controls.assign([player.torso, player.head, player.left_leg, player.left_knee, player.right_leg, player.right_knee, player.left_arm, player.axe_arm, player.axe])
	for i in range(controls.size()):
		var node := controls[i]
		skeleton.add_bone("joint_%d" % i)
		var parent := controls.find(node.get_parent())
		if parent >= 0:
			skeleton.set_bone_parent(i, parent)
		skeleton.set_bone_rest(i, node.transform)
		skeleton.set_bone_pose_position(i, node.position)
		var attachment := BoneAttachment3D.new()
		attachments.append(attachment)
		attachment.bone_name = "joint_%d" % i
		skeleton.add_child(attachment)
		for child in node.get_children():
			if not child in controls:
				child.reparent(attachment, false)
func _process(_delta: float) -> void:
	for i in range(controls.size()):
		if is_instance_valid(controls[i]):
			skeleton.set_bone_pose_position(i, controls[i].position)
			skeleton.set_bone_pose_rotation(i, controls[i].quaternion)
			skeleton.set_bone_pose_scale(i, controls[i].scale)
