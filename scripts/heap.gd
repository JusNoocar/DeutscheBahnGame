extends RefCounted
class_name Heap

class MinHeap:
	# Binary min-heap storing items as {"p": priority, "n": node}
	var data: Array = []

	func is_empty() -> bool:
		return data.is_empty()

	func push(priority: float, node: Variant) -> void:
		data.append({"p": priority, "n": node})
		_sift_up(data.size() - 1)

	func pop() -> Dictionary:
		# Returns {"p": ..., "n": ...}. Caller must ensure heap is not empty.
		var top: Dictionary = data[0]
		var last: Dictionary = data.pop_back()
		if not data.is_empty():
			data[0] = last
			_sift_down(0)
		return top

	func _sift_up(i: int) -> void:
		while i > 0:
			var parent := (i - 1) >> 1  # integer division by 2 (Godot 4-safe)
			if float(data[i]["p"]) < float(data[parent]["p"]):
				var tmp = data[i]
				data[i] = data[parent]
				data[parent] = tmp
				i = parent
			else:
				break

	func _sift_down(i: int) -> void:
		while true:
			var left := 2 * i + 1
			var right := 2 * i + 2
			var smallest := i

			if left < data.size() and float(data[left]["p"]) < float(data[smallest]["p"]):
				smallest = left
			if right < data.size() and float(data[right]["p"]) < float(data[smallest]["p"]):
				smallest = right

			if smallest == i:
				break

			var tmp = data[i]
			data[i] = data[smallest]
			data[smallest] = tmp
			i = smallest
