class_name CargoBarrel
extends Cargo

## Rolling cylindrical cargo variant (axis along local Z). Overrides only the
## shape-specific aim test and grab-point clamping; all networking, damage, carry,
## and stabilize logic is inherited from Cargo. Rolls when nudged and refuses to
## settle, so precise delivery placement becomes the whole challenge.

# CONSTANTS
const RADIUS := 0.6
const HALF_HEIGHT := 1.0 # cylinder length is 2 * HALF_HEIGHT, along local Z


# PUBLIC FUNCTIONS
func aim_hit_distance(eye: Vector3, dir: Vector3, max_dist: float) -> float:
	## Ray-cylinder intersection in local space (side wall first, then end caps).
	var inv := global_transform.affine_inverse()
	var o := inv * eye
	var d := (inv.basis * dir).normalized()
	var a := d.x * d.x + d.y * d.y
	if a >= 0.00001:
		var b := 2.0 * (o.x * d.x + o.y * d.y)
		var c := o.x * o.x + o.y * o.y - RADIUS * RADIUS
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var s := sqrt(disc)
			for t in [(-b - s) / (2.0 * a), (-b + s) / (2.0 * a)]:
				if t < 0.0 or t > max_dist:
					continue
				if absf(o.z + d.z * t) <= HALF_HEIGHT:
					return t
	# Side wall missed (or ray parallel to the axis): try the two end caps.
	var best := -1.0
	if absf(d.z) >= 0.00001:
		for cap_z: float in [HALF_HEIGHT, -HALF_HEIGHT]:
			var t_cap := (cap_z - o.z) / d.z
			if t_cap < 0.0 or t_cap > max_dist:
				continue
			var hx := o.x + d.x * t_cap
			var hy := o.y + d.y * t_cap
			if hx * hx + hy * hy <= RADIUS * RADIUS \
					and (best < 0.0 or t_cap < best):
				best = t_cap
	return best


# PRIVATE FUNCTIONS
func _clamp_grab_point(local: Vector3) -> Vector3:
	# Project onto the cylinder: clamp the axial component, radialise the rest.
	var z := clampf(local.z, -HALF_HEIGHT, HALF_HEIGHT)
	var xy := Vector2(local.x, local.y)
	if xy.length() > RADIUS:
		xy = xy.normalized() * RADIUS
	return Vector3(xy.x, xy.y, z)
