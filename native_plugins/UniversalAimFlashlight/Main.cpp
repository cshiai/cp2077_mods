#include <RED4ext/RED4ext.hpp>
#include <RED4ext/RTTISystem.hpp>
#include <RED4ext/Scripting/Functions.hpp>
#include <RED4ext/Scripting/Utils.hpp>
#include <RED4ext/Scripting/Natives/Generated/Color.hpp>
#include <RED4ext/Scripting/Natives/Generated/CurveSet.hpp>
#include <RED4ext/Scripting/Natives/Generated/ELightShadowSoftnessMode.hpp>
#include <RED4ext/Scripting/Natives/Generated/ELightType.hpp>
#include <RED4ext/Scripting/Natives/Generated/ELightUnit.hpp>
#include <RED4ext/Scripting/Natives/Generated/Quaternion.hpp>
#include <RED4ext/Scripting/Natives/Generated/Vector3.hpp>
#include <RED4ext/Scripting/Natives/Generated/WorldPosition.hpp>
#include <RED4ext/Scripting/Natives/Generated/ent/Entity.hpp>
#include <RED4ext/Scripting/Natives/Generated/ent/HardTransformBinding.hpp>
#include <RED4ext/Scripting/Natives/Generated/ent/IComponent.hpp>
#include <RED4ext/Scripting/Natives/Generated/game/LightComponent.hpp>
#include <RED4ext/Scripting/Natives/Generated/rend/ContactShadowReciever.hpp>
#include <RED4ext/Scripting/Natives/Generated/rend/LightAttenuation.hpp>

namespace
{
RED4ext::v1::PluginHandle g_pluginHandle = nullptr;
const RED4ext::v1::Sdk* g_sdk = nullptr;

bool HasComponentByName(RED4ext::ent::Entity* aEntity, RED4ext::CName aName)
{
    if (!aEntity || aName.IsNone())
    {
        return false;
    }

    for (uint32_t i = 0; i < aEntity->components.size(); ++i)
    {
        const auto& comp = aEntity->components[i];
        if (comp && comp->name == aName)
        {
            return true;
        }
    }

    return false;
}

RED4ext::Handle<RED4ext::game::LightComponent> CreateCameraSpotlight(
    RED4ext::ent::Entity* aOwner, const char* aName, uint64_t aCruid, RED4ext::Color aColor, float aTemperature,
    float aIntensity, float aEV, float aRadius, float aInnerAngle, float aOuterAngle, float aSoftness,
    uint8_t aVolFogScale, bool aEnableShadows)
{
    auto* rtti = RED4ext::CRTTISystem::Get();
    if (!rtti)
    {
        return {};
    }

    auto* bindingCls = rtti->GetClass("entHardTransformBinding");
    auto* lightCls = rtti->GetClass("gameLightComponent");
    if (!bindingCls || !lightCls)
    {
        return {};
    }

    auto* rawBinding = static_cast<RED4ext::ent::HardTransformBinding*>(bindingCls->CreateInstance(true));
    if (!rawBinding)
    {
        return {};
    }
    RED4ext::Handle<RED4ext::ent::HardTransformBinding> binding(rawBinding);
    binding->enabled = true;
    binding->bindName = RED4ext::CNamePool::Add("camera");

    auto* rawLight = static_cast<RED4ext::game::LightComponent*>(lightCls->CreateInstance(true));
    if (!rawLight)
    {
        return {};
    }
    RED4ext::Handle<RED4ext::game::LightComponent> light(rawLight);

    // ent::IComponent
    light->name = RED4ext::CNamePool::Add(aName);
    light->owner = aOwner;
    light->id.unk00 = aCruid;
    light->isEnabled = true;
    light->isReplicable = false;

    // ent::IPlacedComponent
    // Place the default origin 1.05m forward (at the weapon muzzle tip, well ahead of
    // any optic/scope and gun body) and 5cm below the bore axis.
    light->parentTransform = binding;
    light->localTransform.Position = RED4ext::WorldPosition(RED4ext::Vector3(0.02f, 1.05f, -0.05f));
    light->localTransform.Orientation = RED4ext::Quaternion(0.0f, 0.0f, 0.0f, 1.0f);

    // ent::IVisualComponent
    light->autoHideDistance = 250.0f;
    light->forceLODLevel = 0;
    light->renderSceneLayerMask.Default = 1;

    // ent::LightComponent
    light->type = RED4ext::ELightType::LT_Spot;
    light->unit = RED4ext::ELightUnit::LU_Lumen;
    light->color = aColor;
    light->temperature = aTemperature;
    light->intensity = aIntensity;
    light->EV = aEV;
    light->radius = aRadius;
    light->innerAngle = aInnerAngle;
    light->outerAngle = aOuterAngle;
    light->softness = aSoftness;
    light->scaleGI = 100;
    light->scaleEnvProbes = 100;
    light->sceneSpecularScale = 100;
    light->scaleVolFog = aVolFogScale;
    // Disable transparent & particle shading so the beam never causes lens flare on
    // weapon scopes/reflex sights or blinding glare on muzzle smoke when firing.
    light->useInTransparents = false;
    light->useInParticles = false;
    light->sceneDiffuse = true;
    light->directional = false;
    light->clampAttenuation = true;
    light->attenuation = RED4ext::rend::LightAttenuation::LA_InverseSquare;

    light->lightChannel.LC_Channel1 = 1;
    light->lightChannel.LC_Channel2 = 1;
    light->lightChannel.LC_Channel3 = 1;
    light->lightChannel.LC_Channel4 = 1;
    light->lightChannel.LC_Channel5 = 1;
    light->lightChannel.LC_Channel6 = 1;
    light->lightChannel.LC_Channel7 = 1;
    light->lightChannel.LC_Channel8 = 1;
    light->lightChannel.LC_ChannelWorld = 1;
    light->lightChannel.LC_Character = 1;
    light->lightChannel.LC_Player = 0;

    light->enableLocalShadows = aEnableShadows;
    light->contactShadows = aEnableShadows ? RED4ext::rend::ContactShadowReciever::CSR_All
                                           : RED4ext::rend::ContactShadowReciever::CSR_None;
    light->shadowAngle = aOuterAngle;
    light->shadowRadius = aRadius;
    light->shadowFadeDistance = 95.0f;
    light->shadowFadeRange = 25.0f;
    light->shadowSoftnessMode = RED4ext::ELightShadowSoftnessMode::LSSM_Soft;
    light->allowDistantLight = true;
    light->rayTracingIntensityScale = 1.5f;
    light->rtxdiShadowStartingDistance = 0.5f;

    // game::LightComponent
    light->emissiveOnly = false;
    light->turnOnByDefault = false;
    light->onStrength = 1.0f;
    light->turnOnTime = 0.03f;
    light->turnOffTime = 0.04f;
    light->isDestructible = false;

    return light;
}

void Entity_CreateAimFlashlightComponent(RED4ext::IScriptable* aContext, RED4ext::CStackFrame* aFrame,
                                         RED4ext::Handle<RED4ext::ent::IComponent>* aOut, int64_t a4)
{
    RED4EXT_UNUSED_PARAMETER(a4);

    RED4ext::CName componentName;
    RED4ext::GetParameter(aFrame, &componentName);
    aFrame->Step();

    auto* entity = static_cast<RED4ext::ent::Entity*>(aContext);
    if (!entity || componentName.IsNone() || HasComponentByName(entity, componentName))
    {
        if (aOut)
        {
            *aOut = {};
        }
        return;
    }

    const uint64_t entitySeed = entity->entityID.hash ? entity->entityID.hash : reinterpret_cast<uintptr_t>(entity);
    const RED4ext::CName mainName = RED4ext::CNamePool::Add("Flashlight");
    const RED4ext::CName fillName = RED4ext::CNamePool::Add("FlashlightFill");

    RED4ext::Handle<RED4ext::ent::IComponent> created{};
    if (componentName == mainName)
    {
        auto mainLight = CreateCameraSpotlight(
            entity, "Flashlight", 0x2077F1A541164701ULL ^ (entitySeed * 0x9E3779B97F4A7C15ULL),
            RED4ext::Color{255, 250, 242, 255}, 5800.0f, 4500.0f, 6.0f, 120.0f, 22.0f, 55.0f, 2.5f, 0, true);
        created = mainLight;
    }
    else if (componentName == fillName)
    {
        auto fillLight = CreateCameraSpotlight(
            entity, "FlashlightFill", 0x2077F1A541164702ULL ^ (entitySeed * 0xBF58476D1CE4E5B9ULL),
            RED4ext::Color{255, 248, 238, 255}, 5400.0f, 1800.0f, 4.5f, 55.0f, 42.0f, 95.0f, 4.0f, 0, false);
        created = fillLight;
    }

    if (aOut)
    {
        *aOut = created;
    }
}

void PostRegisterTypes()
{
    auto* rtti = RED4ext::CRTTISystem::Get();
    if (!rtti)
    {
        return;
    }

    auto* entityCls = rtti->GetClass("entEntity");
    if (!entityCls)
    {
        if (g_sdk && g_sdk->logger)
        {
            g_sdk->logger->Error(g_pluginHandle, "Failed to locate entEntity in RTTI.");
        }
        return;
    }

    RED4ext::CBaseFunction::Flags flags{};
    flags.isNative = true;
    flags.isFinal = true;
    flags.isPublic = true;

    if (!entityCls->GetFunction("CreateAimFlashlightComponent"))
    {
        auto* createFn = RED4ext::CClassFunction::Create(entityCls, "CreateAimFlashlightComponent",
                                                         "CreateAimFlashlightComponent",
                                                         &Entity_CreateAimFlashlightComponent, flags);
        if (createFn)
        {
            createFn->AddParam("CName", "name");
            createFn->SetReturnType("handle:entIComponent");
            entityCls->RegisterFunction(createFn);
        }
    }

    if (g_sdk && g_sdk->logger)
    {
        g_sdk->logger->Info(g_pluginHandle, "Registered entEntity::CreateAimFlashlightComponent (Codeware-compatible).");
    }
}
} // namespace

RED4EXT_C_EXPORT bool RED4EXT_CALL Main(RED4ext::v1::PluginHandle aHandle, RED4ext::v1::EMainReason aReason,
                                        const RED4ext::v1::Sdk* aSdk)
{
    switch (aReason)
    {
    case RED4ext::v1::EMainReason::Load:
    {
        g_pluginHandle = aHandle;
        g_sdk = aSdk;

        auto* rtti = RED4ext::CRTTISystem::Get();
        if (rtti)
        {
            rtti->AddPostRegisterCallback(&PostRegisterTypes);
        }

        if (aSdk && aSdk->logger)
        {
            aSdk->logger->Info(aHandle, "UniversalAimFlashlight 1.1.0 initialized for Cyberpunk 2077 2.50.");
        }
        break;
    }
    case RED4ext::v1::EMainReason::Unload:
    {
        break;
    }
    }

    return true;
}

RED4EXT_C_EXPORT void RED4EXT_CALL Query(RED4ext::v1::PluginInfo* aInfo)
{
    aInfo->name = L"UniversalAimFlashlight";
    aInfo->author = L"CustomRedscriptSuite";
    aInfo->version = RED4EXT_V1_SEMVER(1, 1, 0);
    aInfo->runtime = RED4EXT_V1_RUNTIME_VERSION_2_50;
    aInfo->sdk = RED4EXT_V1_SDK_VERSION_CURRENT;
}

RED4EXT_C_EXPORT uint32_t RED4EXT_CALL Supports()
{
    return RED4EXT_API_VERSION_1;
}
