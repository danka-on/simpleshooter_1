extends Node

## Pool system autoload for easy access to the object pool system

# The pool manager instance
var _pool_manager: PoolManager = null

# Enumeration of common pool types for easy reference
enum PoolType {
    BULLET,
    EXPLOSION,
    HIT_EFFECT,
    DAMAGE_NUMBER
    # Add more as needed
}

# Dictionary mapping pool types to their string names
var _pool_names: Dictionary = {
    PoolType.BULLET: "bullets",
    PoolType.EXPLOSION: "explosions",
    PoolType.HIT_EFFECT: "hit_effects",
    PoolType.DAMAGE_NUMBER: "damage_numbers"
    # Add more as needed
}

# Paths to common scenes we'll pool
const BULLET_SCENE = "res://scenes/bullet.tscn"
const EXPLOSION_SCENE = "res://scenes/PoolableExplosion.tscn"
const EXPLOSION_FALLBACK_SCENE = "res://scenes/Explosion.tscn"
const HIT_EFFECT_SCENE = "res://scenes/hit_effect.tscn"
const DAMAGE_NUMBER_SCENE = "res://scenes/damage_number.tscn"

func _ready() -> void:
    # Create the pool manager
    _pool_manager = PoolManager.new()
    _pool_manager.name = "PoolManager"
    add_child(_pool_manager)
    
    # Initialize common pools
    _initialize_common_pools()
    
    # Enable explosion debugging if DebugSettings exists
    if has_node("/root/DebugSettings"):
        # By default enable pool and explosion debugging
        DebugSettings.toggle_debug("pools", true)
        DebugSettings.toggle_debug("explosions", true)
    
    print("Pool System initialized!")

## Initialize commonly used object pools
func _initialize_common_pools() -> void:
    print("PoolSystem: Initializing common object pools...")
    
    # Load common scenes
    var bullet_scene: PackedScene = load(BULLET_SCENE)
    
    # Try to load the poolable explosion scene first, fall back to regular if needed
    var explosion_scene: PackedScene = null
    explosion_scene = load(EXPLOSION_SCENE)
    
    if explosion_scene == null:
        print("PoolSystem: Poolable explosion scene not found, falling back to regular explosion")
        explosion_scene = load(EXPLOSION_FALLBACK_SCENE)
    else:
        print("PoolSystem: Successfully loaded poolable explosion scene: " + EXPLOSION_SCENE)
        # Debug check for the scene's script
        var temp_instance = explosion_scene.instantiate()
        if temp_instance and temp_instance.get_script():
            print("PoolSystem: Explosion scene uses script: " + temp_instance.get_script().resource_path)
            # Check if this is actually a PoolableExplosion
            if temp_instance is PoolableExplosion:
                print("PoolSystem: Confirmed scene is a PoolableExplosion instance")
            else:
                print("PoolSystem: WARNING - Scene is NOT a PoolableExplosion instance!")
        else:
            print("PoolSystem: WARNING - Explosion scene has no script attached!")
        temp_instance.queue_free()
    
    var hit_effect_scene: PackedScene = load(HIT_EFFECT_SCENE)
    var damage_number_scene: PackedScene = load(DAMAGE_NUMBER_SCENE)
    
    # Create pools with appropriate initial sizes
    if bullet_scene:
        _pool_manager.create_pool(_pool_names[PoolType.BULLET], bullet_scene, 20)
        print("PoolSystem: Created bullet pool with initial size of 20")
    else:
        push_warning("PoolSystem: Failed to load bullet scene at " + BULLET_SCENE)
    
    if explosion_scene:
        _pool_manager.create_pool(_pool_names[PoolType.EXPLOSION], explosion_scene, 10)
        print("PoolSystem: Created explosion pool with initial size of 10")
    else:
        push_warning("PoolSystem: Failed to load explosion scene at " + EXPLOSION_SCENE)
    
    if hit_effect_scene:
        _pool_manager.create_pool(_pool_names[PoolType.HIT_EFFECT], hit_effect_scene, 30)
        print("PoolSystem: Created hit effect pool with initial size of 30")
    else:
        push_warning("PoolSystem: Failed to load hit effect scene at " + HIT_EFFECT_SCENE)
    
    if damage_number_scene:
        _pool_manager.create_pool(_pool_names[PoolType.DAMAGE_NUMBER], damage_number_scene, 20)
        print("PoolSystem: Created damage number pool with initial size of 20")
    else:
        push_warning("PoolSystem: Failed to load damage number scene at " + DAMAGE_NUMBER_SCENE)
    
    print("PoolSystem: Pool initialization complete")

## Get an object from a pool using the PoolType enum
func get_object(pool_type: PoolType) -> Node:
    if not _pool_names.has(pool_type):
        push_error("PoolSystem: Invalid pool type: %d" % pool_type)
        return null
    
    var pool_name = _pool_names[pool_type]
    print("[POOL_DEBUG] Requesting object from pool: %s (type: %d)" % [pool_name, pool_type])
    
    var obj = _pool_manager.get_object(pool_name)
    
    if obj:
        print("[POOL_DEBUG] Got object ID:%d from pool: %s" % [obj.get_instance_id(), pool_name])
    else:
        print("[POOL_DEBUG] Failed to get object from pool: %s (returned null)" % pool_name)
    
    return obj

## Release an object back to its pool
func release_object(obj: Node) -> void:
    if obj:
        var obj_id = obj.get_instance_id()
        print("[POOL_DEBUG] Releasing object ID:%d back to pool" % obj_id)
        
        # Try to find which pool this object belongs to
        for pool_name in _pool_names.values():
            var pool = _pool_manager.get_pool(pool_name)
            if pool and pool._active_objects.has(obj):
                print("[POOL_DEBUG] Object ID:%d belongs to pool: %s" % [obj_id, pool_name])
                break
        
        _pool_manager.release_object(obj)
    else:
        print("[POOL_DEBUG] ERROR: Attempted to release null object to pool")

## Create a custom pool with a specific scene
func create_custom_pool(pool_name: String, scene_path: String, initial_size: int = 10, max_size: int = -1) -> ObjectPool:
    var scene: PackedScene = load(scene_path)
    if not scene:
        push_error("PoolSystem: Failed to load scene: %s" % scene_path)
        return null
    
    return _pool_manager.create_pool(pool_name, scene, initial_size, max_size)

## Get a reference to a specific pool by name
func get_pool(pool_name: String) -> ObjectPool:
    return _pool_manager.get_pool(pool_name)

## Check if a pool with the given name exists
func has_pool(pool_name: String) -> bool:
    return _pool_manager.has_pool(pool_name)

## Get a reference to a specific pool by pool type
func get_pool_by_type(pool_type: PoolType) -> ObjectPool:
    if not _pool_names.has(pool_type):
        push_error("PoolSystem: Invalid pool type: %d" % pool_type)
        return null
    
    return _pool_manager.get_pool(_pool_names[pool_type])

## Get statistics about all pools
func get_stats() -> Dictionary:
    return _pool_manager.get_pool_counts()

## Get the raw pool manager instance
func get_pool_manager() -> PoolManager:
    return _pool_manager

## Clean up invalid objects in all pools
func cleanup_pools() -> void:
    if _pool_manager:
        _pool_manager.cleanup_all_pools()

## Print debug information about all pools
func debug_pools() -> void:
    if _pool_manager:
        var stats = get_stats()
        print("\n=== POOL SYSTEM DEBUG INFO ===")
        
        for pool_name in stats:
            var pool_stat = stats[pool_name]
            print("%s: %d active, %d available, %d total" % [
                pool_name, 
                pool_stat.active, 
                pool_stat.available, 
                pool_stat.total
            ])
            
            # Get actual objects in the pool
            var pool = _pool_manager.get_pool(pool_name)
            if pool:
                print("  Active objects:")
                for obj in pool._active_objects:
                    if is_instance_valid(obj):
                        print("    - ID: %d, Type: %s" % [obj.get_instance_id(), obj.get_class()])
                    else:
                        print("    - INVALID OBJECT")
                        
                print("  Available objects: %d" % pool._available_objects.size())
        
        print("==============================\n") 

## Print detailed statistics for all pools
func print_all_pool_stats() -> void:
    if _pool_manager:
        print("\n========== OBJECT POOL SYSTEM STATISTICS ==========")
        
        var total_objects = 0
        var total_active = 0
        var total_available = 0
        var total_created = 0
        var total_cache_misses = 0
        
        for pool_name in _pool_manager.get_pool_names():
            var pool = _pool_manager.get_pool(pool_name)
            if pool:
                pool.print_detailed_stats()
                
                # Accumulate totals
                var stats = pool.get_detailed_stats()
                total_objects += stats.total_current
                total_active += stats.active
                total_available += stats.available
                total_created += stats.total_created
                total_cache_misses += stats.cache_misses
        
        # Print grand totals
        print("=== SYSTEM TOTALS ===")
        print("Total pools: %d" % _pool_manager.get_pool_names().size())
        print("Total objects in system: %d" % total_objects)
        print("Total active objects: %d" % total_active)
        print("Total available objects: %d" % total_available)
        print("Total objects created: %d" % total_created)
        print("Total cache misses: %d" % total_cache_misses)
        if total_created > 0:
            print("System-wide cache hit rate: %.1f%%" % ((total_created - total_cache_misses) / float(total_created) * 100))
        print("================================================\n")
        
        # Log summary to DebugSettings if available
        if has_node("/root/DebugSettings"):
            DebugSettings.debug_print("performance", 
                "Pool System: %d total objects (%d active, %d available) across %d pools" % 
                [total_objects, total_active, total_available, _pool_manager.get_pool_names().size()], 
                DebugSettings.LogLevel.INFO)
    else:
        print("PoolSystem: No pool manager initialized")

## Reset all pools, clearing them and recreating with fresh objects
func reset_all_pools() -> void:
    if _pool_manager:
        for pool_name in _pool_manager.get_pool_names():
            var pool = _pool_manager.get_pool(pool_name)
            if pool:
                pool.reset_pool()
        
        print("All pools have been reset")
        
        # Log to DebugSettings if available
        if has_node("/root/DebugSettings"):
            DebugSettings.debug_print("pools", "All object pools have been reset with fresh objects", 
                DebugSettings.LogLevel.INFO)
    else:
        print("PoolSystem: No pool manager initialized") 
