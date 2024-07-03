package game

DEFAULT_WORLD_NAME := "default"

Seq :: distinct u64

// ------ World ------ \\

World :: struct {
	name: string,
	seq: Seq, // current sequence number
	entities: [dynamic]Entity,
	systems: [dynamic]System,
}

world_init :: proc(name: string) -> World {
	return World{
		name = name,
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
	for &e in w.entities {
		entity_destroy(&e)
	}
	delete(w.entities)
	delete(w.systems)
}

// ------ Entity ------ \\

Entity :: struct {
	id: Seq,
	components: map[typeid]rawptr,
}

entity_create :: proc(w: ^World) -> Entity {
	e := Entity{
		id = w.seq,
		components = make(map[typeid]rawptr),
	}
	w.seq += 1
	append(&w.entities, e)
	return e
}

entity_destroy :: proc(e: ^Entity) {
	for k, v in e.components {
		free(v)
		delete_key(&e.components, k)
	}
	delete(e.components)
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
