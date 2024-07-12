package game

DEFAULT_WORLD_NAME := "default"

import "core:reflect"

Seq :: distinct u64

// ------ World ------ \\

World :: struct {
	name: string,
	seq: Seq, // current sequence number
	entities: map[typeid][dynamic]rawptr,
	systems: [dynamic]System,
}

world_init :: proc(name: string) -> World {
	return World{
		name = name,
		entities = make(map[typeid][dynamic]rawptr),
	}
}

world_update :: proc(w: ^World) {
	for s in w.systems {
		if s.update != nil {
			s.update(w)
		}
	}
}

world_draw :: proc(w: ^World) {
	for s in w.systems {
		if s.draw != nil {
			s.draw(w)
		}
	}
}

world_destroy :: proc(w: ^World) {
	for _, &type_array in w.entities {
		for entity in type_array {
			entity_ptr := cast(^Entity)entity
			entity_destroy(w, entity_ptr)
		}
		delete(type_array)
	}

	delete(w.entities)
	delete(w.systems)
}

// ------ Entity ------ \\

Entity :: struct {
	id: Seq,
	components: map[typeid]rawptr,
}

entity_create :: proc(w: ^World, $T: typeid, value: ^T) -> T {
	w.seq += 1

	if w.entities[T] == nil {
		w.entities[T] = make([dynamic]rawptr)
	}

	type_info := type_info_of(T)
	if named_type, is_named := type_info.variant.(reflect.Type_Info_Named); is_named {
		base_type_info := named_type.base
		if struct_info, is_struct := base_type_info.variant.(reflect.Type_Info_Struct); is_struct {
			for name, i in struct_info.names {
				if name == "entity" {
					field := struct_info.types[i]
					if field.id == typeid_of(Entity) {
						entity_ptr := (^Entity)(uintptr(value) + struct_info.offsets[i])
						entity_ptr.id = w.seq
						entity_ptr.components = make(map[typeid]rawptr, 32)
						break
					}
				}
			}
		}
	}

	append(&w.entities[T], value)
	return value^
}

entity_get :: proc(w: ^World, $T: typeid) -> T {
	if type_array, exists := w.entities[typeid_of(T)]; exists && len(type_array) > 0 {
		any_value := any{type_array[0], typeid_of(T)}

		if v, is_type := any_value.(T); is_type {
			return v
		}

		if ptr, is_ptr := any_value.(^T); is_ptr {
			return ptr^
		}
	}
	return {}
}

entity_destroy :: proc(w: ^World, entity: ^Entity) {
	for type_id, &type_array in w.entities {
		for i := 0; i < len(type_array); i += 1 {
			if cast(^Entity)type_array[i] == entity {
				ordered_remove(&type_array, i)

				for _, component in entity.components {
					free(component)
				}
				delete(entity.components)

				free(entity)

				if len(type_array) == 0 {
					delete(type_array)
					delete_key(&w.entities, type_id)
				}

				return
			}
		}
	}
}

entities_get :: proc(w: ^World, $T: typeid) -> []T {
	if type_array, exists := w.entities[typeid_of(T)]; exists && len(type_array) > 0 {
		result := make([]T, len(type_array))
		for i in 0..<len(type_array) {
			any_value := any{type_array[i], typeid_of(T)}
			if v, is_type := any_value.(T); is_type {
				result[i] = v
			} else if ptr, is_ptr := any_value.(^T); is_ptr {
				result[i] = ptr^
			}
		}
		return result
	}
	return nil
}

entities_get_all :: proc(w: ^World) -> [dynamic]^Entity {
	result := make([dynamic]^Entity)
	for _, type_array in w.entities {
		for entity_ptr in type_array {
			entity := cast(^Entity)entity_ptr
			append(&result, entity)
		}
	}
	return result
}

// ------ Component ------ \\

component_add :: proc(e: ^Entity, component: $T) {
	ptr := new(T)
	ptr^ = component
	e.components[typeid_of(T)] = rawptr(ptr)
}

component_get :: proc(e: ^Entity, $T: typeid) -> ^T {
	for k, v in e.components {
		if k == typeid_of(T) {
			return (^T)(v)
		}
	}
	return nil
}

component_remove :: proc(e: ^Entity, $T: typeid) -> bool {
	for i in e.components {
		if _, ok := e.components[i].(T); ok {
			ordered_remove(&e.components, i)
			return true
		}
	}
	return false
}

// ------ System ------ \\

System_Update_Proc :: #type proc(w: ^World)
System_Draw_Proc :: #type proc(w: ^World)

System :: struct {
	update: System_Update_Proc,
	draw: System_Draw_Proc,
}

system_add :: proc(w: ^World, s: System) {
	append(&w.systems, s)
}

system_destroy :: proc(w: ^World, s: System) {
	for _, i in w.systems {
		if s == w.systems[i] {
			ordered_remove(&w.systems, i)
		}
	}
}
