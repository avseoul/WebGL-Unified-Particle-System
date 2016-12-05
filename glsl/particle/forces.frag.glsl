#version 100
#extension GL_EXT_draw_buffers: enable

precision highp float;
precision highp int;

uniform sampler2D u_posTex;
uniform sampler2D u_velTex;
uniform int u_side;
uniform float u_diameter;
uniform float u_dt;
uniform float u_bound;

varying vec2 v_uv;

vec2 getUV(int idx, int side) {
    float v = float(idx / side) / float(side);
    float u = float(idx - (idx / side) * side) / float(side);
    return vec2(u, v);
}

void main() {
    // Spring coefficient
    float k = 400.0;
    float bounds_k = 200.0;

    // Damping coefficient
    float n = 4.0;
    // Friction coefficient
    float u = 1.0;

    vec3 spring_total = vec3(0.0);
    vec3 damping_total = vec3(0.0);
    vec3 pos = texture2D(u_posTex, v_uv).xyz;
    vec3 vel = texture2D(u_velTex, v_uv).xyz;

    // Naive loop through all particles
    // Hack because WebGL cannot compare loop index to non-constant expression
    // Maximum of 1024x1024 = 1048576 for now
    for (int i = 0; i < 1048576; i++) {
        if (i == u_side * u_side)
            break;

        vec2 uv = getUV(i, u_side);

        vec3 p_pos = texture2D(u_posTex, uv).xyz;
        if (length(p_pos - pos) < 0.001)
            continue;
        vec3 p_vel = texture2D(u_velTex, uv).xyz;

        vec3 rel_pos = p_pos - pos;
        vec3 rel_vel = p_vel - vel;
        if (length(rel_pos) < u_diameter) {
            spring_total += -k * (u_diameter - length(rel_pos)) * normalize(rel_pos);
            damping_total += n * rel_vel;
        }
    }

    vec3 force = spring_total + damping_total;
    force.y -= 9.8;

    //Predict next position
    vec3 newPos = pos + vel * u_dt;

    bool applyFriction = false;
    //Boundary conditions
    if (newPos.y < u_diameter / 2.0) {
        // Negate gravity if contacting ground
        force.y += 9.8;
        applyFriction = true;
    }
    if (abs(newPos.x) > u_bound) {
        force.x += bounds_k * (u_bound - abs(newPos.x)) * sign(newPos.x);
        applyFriction = true;
    }
    if (abs(newPos.z) > u_bound) {
        force.z += bounds_k * (u_bound - abs(newPos.z)) * sign(newPos.z);
        applyFriction = true;
    }
    //Apply friction if contacting the boundary
    vec3 dir = normalize(vel);
    if(applyFriction && length(dir) > 0.0) {
        force += -1.0 * dir * u;
    }

    gl_FragData[2] = vec4(force, 1.0); //force output
}