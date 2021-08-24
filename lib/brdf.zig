const std = @import("std");
const math = std.math;

const affine = @import("affine.zig");
const V3 = affine.V3;
const v3 = V3.init;

const invPi: f64 = 0.31830988618379067;
const invTau: f64 = 0.15915494309189534;

const Jazbz = @import("jabz.zig").Jazbz(f64);

const gmath = @import("gmath.zig").gmath(f64);
const clamp = gmath.clamp;
const saturate = gmath.saturate;
const sq = gmath.sq;
const gmix = gmath.mix;

/// https://google.github.io/filament/Filament.html#materialsystem/standardmodelsummary
pub const Material = struct {
    const Self = @This();

    baseColor: Jazbz = Jazbz.grey(0.5),

    /// Metallic is almost a binary value. Use values very close to 0 and 1. Intermediate values are for transitions between surface types, e.g., metal to rust.
    metallic: f64 = 0,

    /// Roughness clamped to 0.045 to avoid division by zero and aliasing.
    roughness: f64 = 0.5,

    /// Common reflectance: water→0.35, fabric→0.5-0.59, common-liquids→0.35-0.5, common-gemstones→0.56-1, plastics/glass→0.5-0.56, other dielectrics→0.35-0.56, eyes→0.39, skin→0.42, hair→0.54, teeth→0.6, default→0.5
    /// Reflectance is ignored for metallic materials.
    reflectance: f64 = 0,

    /// Strength of the clear coat layer
    clearcoat: f64 = 0,

    /// Perceived smoothness or roughness of the clear coat layer.
    clearcoatRoughness: f64 = 0,

    pub fn mix(self: Self, other: Self, alpha: f64) Self {
        return .{
            .baseColor = gmix(self.baseColor, other.baseColor, alpha),
            .metallic = gmix(self.metallic, other.metallic, alpha),
            .roughness = gmix(self.roughness, other.roughness, alpha),
            .reflectance = gmix(self.reflectance, other.reflectance, alpha),
            .clearcoat = gmix(self.clearcoat, other.clearcoat, alpha),
            .clearcoatRoughness = gmix(self.clearcoatRoughness, other.clearcoatRoughness, alpha),
        };
    }

    /// https://google.github.io/filament/Filament.html#materialsystem/parameterization/craftingphysicallybasedmaterials
    fn baseColorRemapped(self: *const Self) Jazbz {
        const j = self.baseColor.j;
        const metallicMaterials = gmix(0.67, 1, j);
        const nonMetallicMaterials = gmix(0.2, 0.94, j);
        return .{
            .j = gmix(nonMetallicMaterials, metallicMaterials, self.metallic),
            .azbz = self.baseColor.azbz,
        };
    }

    pub fn prepare(material: *const Self) PreparedMaterial {
        const dieletricf0 = Jazbz.grey(0.16 * sq(material.reflectance));
        const metallicf0 = material.baseColorRemapped();

        return PreparedMaterial{
            .material = material,
            .diffuseColor = material.baseColorRemapped().scaleJ(1 - material.metallic),
            .roughness = clamp(0.045, 1, sq(material.roughness)),
            .clearcoatRoughness = clamp(0.045, 1, sq(material.clearcoatRoughness)),
            .f0 = gmix(dieletricf0, metallicf0, material.metallic),
        };
    }
};

pub const PreparedMaterial = struct {
    const Self = @This();

    material: *const Material,
    diffuseColor: Jazbz,
    roughness: f64,
    clearcoatRoughness: f64,
    f0: Jazbz,

    /// https://google.github.io/filament/Filament.html#materialsystem/standardmodelsummary
    pub fn brdf(self: *const Self, surfaceNormal: V3, viewDirection: V3, lightDirection: V3) Jazbz {
        const material = self.material;

        const n: V3 = surfaceNormal;
        const v: V3 = viewDirection;
        const l: V3 = lightDirection;

        const h: V3 = v.add(l).normalize();

        const NoV: f64 = math.fabs(n.dot(v)) + 1e-5;
        const NoL = saturate(n.dot(l));
        const NoH = saturate(n.dot(h));
        const LoH = saturate(l.dot(h));

        const metallicf0 = material.baseColorRemapped();
        const dieletricf0 = Jazbz.grey(0.16 * sq(material.reflectance));

        const f90: f64 = gmix(0.5, 2.5, sq(LoH) * self.roughness); // TODO: took this f90 from Fd_Burley, not sure what should be used

        const D: f64 = D_GGX(NoH, self.roughness);
        const V: f64 = V_SmithGGXCorrelated(NoV, NoL, self.roughness);
        const F: Jazbz = F_Schlick_color(self.f0, f90, LoH);

        const Dc: f64 = D_GGX(NoH, self.clearcoatRoughness);
        const Vc: f64 = V_SmithGGXCorrelated(NoV, NoL, self.clearcoatRoughness);
        //const Vc: f64 = V_Kelemen(LoH) * self.clearcoatRoughness;
        const clearcoatStrength: f64 = material.clearcoat * F_Schlick(0.04, 1, LoH);
        const clearcoatDamp: f64 = 1 - clearcoatStrength;

        var clearcoat = Jazbz.grey(clearcoatStrength * Dc * Vc);
        var specular: Jazbz = F.scaleJ(D * V);
        var diffuse: Jazbz = self.diffuseColor.scaleJ(Fd_Burley(NoV, NoL, LoH, self.roughness));
        //const diffuse = self.diffuseColor.scaleJ(Fd_Lambert());

        //var sheen: Jazbz = Jazbz.grey(D_Charlie(NoH, self.roughness) * 0.02);

        specular = specular.scaleJ(0.3);
        diffuse = diffuse.scaleJ(0.7);
        clearcoat = clearcoat.scaleJ(1);

        return specular.scaleJ(clearcoatDamp).addLight(diffuse).scaleJ(clearcoatDamp).addLight(clearcoat).toJazbz();
    }
};

fn D_GGX(NoH: f64, roughness: f64) f64 {
    return sq(roughness / (1 - sq(NoH) + sq(NoH * roughness))) * invPi;
}

fn V_SmithGGXCorrelated(NoV: f64, NoL: f64, roughness: f64) f64 {
    const a2 = sq(roughness);
    const GGXV = NoL * math.sqrt(sq(NoV) * (1 - a2) + a2);
    const GGXL = NoV * math.sqrt(sq(NoL) * (1 - a2) + a2);
    return 0.5 / (GGXV + GGXL);
}

fn V_SmithGGXCorrelatedFast(NoV: f64, NoL: f64, roughness: f64) f64 {
    const a = roughness;
    const GGXV = NoL * (NoV * (1 - a) + a);
    const GGXL = NoV * (NoL * (1 - a) + a);
    return 0.5 / (GGXV + GGXL);
}

fn F_Schlick(f0: f64, f90: f64, VoH: f64) f64 {
    return gmix(f0, f90, gmath.pow5(1 - VoH));
}

fn F_Schlick_color(f0: Jazbz, f90: f64, VoH: f64) Jazbz {
    return gmix(f0, Jazbz.grey(f90), gmath.pow5(1 - VoH));
}

fn Fd_Lambert() f64 {
    return invPi;
}

fn Fd_Burley(NoV: f64, NoL: f64, LoH: f64, roughness: f64) f64 {
    const f90: f64 = gmix(0.5, 2.5, sq(LoH) * roughness);
    const lightScatter: f64 = F_Schlick(1, f90, NoL);
    const viewScatter: f64 = F_Schlick(1, f90, NoV);
    return lightScatter * viewScatter * invPi;
}

fn V_Kelemen(LoH: f64) f64 {
    return 0.25 / sq(LoH);
}

fn D_Charlie(NoH: f64, roughness: f64) f64 {
    const invAlpha = 1 / roughness;
    const sin2h = math.max(1 - sq(NoH), 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
    return gmath.pow(sin2h, invAlpha * 0.5) * (invAlpha * invTau + invPi);
}

fn V_Neubelt(NoV: f64, NoL: f64) f64 {
    return saturate(0.25(NoL + NoV - NoL * NoV));
}

fn distributionCloth(Noh: f64, roughness: f64) f64 {
    return D_Charlie(NoH, roughness);
}

fn visibilityCloth(NoV: f64, NoL: f64) f64 {
    return V_Neubelt(NoV, NoL);
}
