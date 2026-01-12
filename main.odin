package poisson

import "core:math"
import "core:math/rand"
import "core:slice"
import "vendor:raylib"

Vector2 :: raylib.Vector2

max_num_cell :: proc(dims: [2]int, r: f32) -> (int, [2]int) {
    cell_size := r / math.sqrt(f32(2))
    cell_dims: [2]int
    cell_dims[0] = int(math.ceil(f32(dims[0]) / cell_size))
    cell_dims[1] = int(math.ceil(f32(dims[1]) / cell_size))
    return cell_dims[0] * cell_dims[1], cell_dims
}

// Uniform sampling in a 2D annulus
rand_uniform_annulus :: proc(center: Vector2, r1, r2: f32) -> Vector2 {
    // To be truly uniform by area in 2D, we use the sqrt of the uniform distribution
    r1_sq := r1 * r1
    r2_sq := r2 * r2
    u := rand.float32_uniform(0, 1)
    radius := math.sqrt(u * (r2_sq - r1_sq) + r1_sq)
    
    theta := rand.float32_uniform(0, 2 * math.PI)
    
    return Vector2{
        center.x + radius * math.cos(theta),
        center.y + radius * math.sin(theta),
    }
}

poisson_sampling :: proc(world_dims: [2]int, r: f32, k: int, x0: Vector2, points: []Vector2) -> int {
    cell_size := r / math.sqrt(f32(2))
    num_cells, grid_dims := max_num_cell(world_dims, r)
    
    grid := make([]int, num_cells)
    defer delete(grid)
    slice.fill(grid, -1)

    // Helper to get grid index for Vector2
    get_grid_idx :: proc(p: Vector2, g_dims: [2]int, c_size: f32) -> int {
        xi := clamp(int(p.x / c_size), 0, g_dims[0] - 1)
        yi := clamp(int(p.y / c_size), 0, g_dims[1] - 1)
        return yi * g_dims[0] + xi
    }

    // Step 1: Initialize
    points[0] = x0
    grid[get_grid_idx(x0, grid_dims, cell_size)] = 0
    current_idx := 1

    active_list := make([dynamic]int, 0, len(points))
    defer delete(active_list)
    append(&active_list, 0)

    r_sq := r * r

    // Step 2: Sample
    sampling: for len(active_list) > 0 {
        idx_in_active := rand.int_range(0, len(active_list))
        center_pt_idx := active_list[idx_in_active]
        center := points[center_pt_idx]
        found := false

        k_iter: for _ in 0..<k {
            candidate := rand_uniform_annulus(center, r, 2 * r)

            // Correct Boundary Check (Pixels)
            if candidate.x < 0 || candidate.x >= f32(world_dims[0]) || 
               candidate.y < 0 || candidate.y >= f32(world_dims[1]) {
                continue k_iter
            }

            // Spatial Check
            c_grid_x := int(candidate.x / cell_size)
            c_grid_y := int(candidate.y / cell_size)
            
            valid := true
            check_neighbors: for y := c_grid_y - 1; y <= c_grid_y + 1; y += 1 {
                for x := c_grid_x - 1; x <= c_grid_x + 1; x += 1 {
                    if x < 0 || x >= grid_dims[0] || y < 0 || y >= grid_dims[1] do continue
                    
                    neighbor_pt_idx := grid[y * grid_dims[0] + x]
                    if neighbor_pt_idx != -1 {
                        dist_sq := raylib.Vector2DistanceSqrt(candidate, points[neighbor_pt_idx])
                        if dist_sq < r_sq {
                            valid = false
                            break check_neighbors
                        }
                    }
                }
            }

            if valid {
                points[current_idx] = candidate
                grid[get_grid_idx(candidate, grid_dims, cell_size)] = current_idx
                append(&active_list, current_idx)
                current_idx += 1
                found = true
                if current_idx >= len(points) do break sampling
                break k_iter
            }
        }

        if !found {
            unordered_remove(&active_list, idx_in_active)
        }
    }
    return current_idx
}

main :: proc() {
    SCREEN_WIDTH  :: 800
    SCREEN_HEIGHT :: 450
    
    raylib.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Poisson Disk Sampling - Vector2 Fixed")
    defer raylib.CloseWindow()
    raylib.SetTargetFPS(60)

    pos := Vector2{f32(SCREEN_WIDTH) / 2, f32(SCREEN_HEIGHT) / 2}
    world_dims := [2]int{SCREEN_WIDTH, SCREEN_HEIGHT}
    radius: f32 = 12.0
    k := 30
    
    max_pts, _ := max_num_cell(world_dims, radius)
    points := make([]Vector2, max_pts)
    defer delete(points)

    num_pts := poisson_sampling(world_dims, radius, k, pos, points)

    for !raylib.WindowShouldClose() {
        if raylib.IsMouseButtonDown(.LEFT) {
            pos = raylib.GetMousePosition()
            num_pts = poisson_sampling(world_dims, radius, k, pos, points)
        }

        raylib.BeginDrawing()
        raylib.ClearBackground(raylib.RAYWHITE)

        for i in 0..<num_pts {
            raylib.DrawCircleV(points[i], 2, raylib.DARKBLUE)
        }

        raylib.DrawCircleV(pos, 4, raylib.RED)
        raylib.EndDrawing()
    }
}
