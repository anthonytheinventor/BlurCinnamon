uniform sampler2D tex;
uniform float sigma;
uniform int dir;
uniform float brightness;
uniform float width;
uniform float height;

// Blur along one axis. The other coordinate is the same for every tap, so it is clamped once here instead of
// per tap; the moving coordinate is offset and clamped exactly as before, so the result is bit-identical.
vec4 blurAxis(float pos, float fixedPos, bool vertical, float pixel_step, float size, float fixedSize) {
    float lo = 3. / size;
    float hi = 1. - 3. / size;
    float fixedClamped = clamp(fixedPos, 3. / fixedSize, 1. - 3. / fixedSize);

    vec3 gauss_coefficient;
    gauss_coefficient.x = 1.0 / (sqrt(2.0 * 3.14159265) * sigma);
    gauss_coefficient.y = exp(-0.5 / (sigma * sigma));
    gauss_coefficient.z = gauss_coefficient.y * gauss_coefficient.y;

    float gauss_coefficient_total = gauss_coefficient.x;

    float p = clamp(pos, lo, hi);
    vec4 ret = texture2D(tex, vertical ? vec2(fixedClamped, p) : vec2(p, fixedClamped)) * gauss_coefficient.x;
    gauss_coefficient.xy *= gauss_coefficient.yz;

    int n_steps = int(ceil(1.5 * sigma)) * 2;

    for (int i = 1; i <= n_steps; i += 2) {
        float coefficient_subtotal = gauss_coefficient.x;
        gauss_coefficient.xy *= gauss_coefficient.yz;
        coefficient_subtotal += gauss_coefficient.x;
        if (coefficient_subtotal <= 0.0)
            break;

        float gauss_ratio = gauss_coefficient.x / coefficient_subtotal;

        float offset = (float(i) + gauss_ratio) * pixel_step;
        float a = clamp(pos + offset, lo, hi);
        float b = clamp(pos - offset, lo, hi);

        ret += texture2D(tex, vertical ? vec2(fixedClamped, a) : vec2(a, fixedClamped)) * coefficient_subtotal;
        ret += texture2D(tex, vertical ? vec2(fixedClamped, b) : vec2(b, fixedClamped)) * coefficient_subtotal;

        gauss_coefficient_total += 2.0 * coefficient_subtotal;
        gauss_coefficient.xy *= gauss_coefficient.yz;
    }
    return ret / gauss_coefficient_total;
}

void blurcinnamon_main() {
    vec2 uv = cogl_tex_coord_in[0].xy;
    vec4 outColor;

    if (dir == 0) {
        outColor = blurAxis(uv.y, uv.x, true, 1.0 / height, height, width);
        // apply brightness on the second pass (dir==0 comes last)
        outColor.rgb *= brightness;
    } else {
        outColor = blurAxis(uv.x, uv.y, false, 1.0 / width, width, height);
    }

    cogl_color_out = outColor;
}

// Apply the actor's paint opacity. ClutterOffscreenEffect passes the actor's paint opacity to the final
// on-screen pass only as the (premultiplied) pipeline colour, cogl_color_in. Inner passes in an effect chain
// are rendered with the opacity forced to 255 (cogl_color_in == 1), so multiplying in every shader applies
// the opacity exactly once. Without this, actor.opacity has no effect on any actor using these effects.
void main() {
    blurcinnamon_main();
    cogl_color_out *= cogl_color_in;
}
