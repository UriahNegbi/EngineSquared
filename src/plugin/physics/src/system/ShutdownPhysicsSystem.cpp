#include "system/ShutdownPhysicsSystem.hpp"
#include "Physics.pch.hpp"

#include "resource/PhysicsManager.hpp"

namespace Physics::System {

void ShutdownPhysicsSystem(Engine::Core &core)
{
    // Jolt-owned resources must be destroyed before its type registry and
    // global factory. PhysicsManager owns the PhysicsSystem and worker pool.
    if (core.HasResource<Resource::PhysicsManager>())
    {
        core.DeleteResource<Resource::PhysicsManager>();
    }

    if (JPH::Factory::sInstance)
    {
        JPH::UnregisterTypes();
        delete JPH::Factory::sInstance;
        JPH::Factory::sInstance = nullptr;
    }
}

} // namespace Physics::System
