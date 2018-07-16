#include <vpi_user.h>
#include <SDL.h>
#include <stdint.h>

SDL_Surface *surface;
unsigned int width, height;
unsigned int last_time = 0;
unsigned int pclk_len = 0;
unsigned int line_len = 0;
unsigned int line_count = 0;
unsigned int x = 0, y = 0;
int in_hsync = 0, in_vsync = 0;
int offset_x = 0, offset_y = 0;
int offset_delta_x = 0, offset_delta_y = 0;
int clocks_until_update_offset = 0;

vpiHandle r, g, b, hsync, vsync, pclk;
unsigned int rmax, gmax, bmax;

static void vgasim_events() {
    // Allow the simulation to be ended by closing the SDL window.
    SDL_Event event;

    while (SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_QUIT:
                vpi_sim_control(vpiFinish, 0);
                break;
            case SDL_KEYDOWN:
                switch (event.key.keysym.sym) {
                    case 273: // UP
                        offset_delta_y = -1; break;
                    case 274: // DOWN
                        offset_delta_y = 1; break;
                    case 276: // LEFT
                        offset_delta_x = -1; break;
                    case 275: // RIGHT
                        offset_delta_x = 1; break;
                }
                break;
            case SDL_KEYUP:
                offset_delta_x = 0;
                offset_delta_y = 0;
                break;
        }
    }

    if (clocks_until_update_offset == 0) {
        offset_x += offset_delta_x;
        offset_y += offset_delta_y;
        clocks_until_update_offset = 255;
    }
    else {
        clocks_until_update_offset--;
    }
}

static int vgasim_pixel_cb(s_cb_data *cb_data) {
    // Only draw a pixel on a rising pixel clock.
    if (! cb_data->value->value.integer) {
        return 0;
    }

    struct t_vpi_value value;
    value.format = vpiIntVal;
    SDL_Rect clear_rect;
    clear_rect.x = 0;
    clear_rect.y = 0;
    clear_rect.w = width;
    clear_rect.h = 1;

    // For now we consider only the low clock, since we generally
    // care only about differences anyway.
    unsigned int time = cb_data->time->low;
    unsigned int last_pclk_len = pclk_len;
    pclk_len = time - last_time;
    if (pclk_len != last_pclk_len) {
        if (last_pclk_len > 0) {
            vpi_printf(
                "WARNING: Pixel clock period changed from %i to %i\n",
                last_pclk_len, pclk_len
            );
        }
        else {
            vpi_printf(
                "Pixel clock period is %i\n", pclk_len
            );
        }
    }
    last_time = time;

    unsigned int rval, gval, bval;

    // Capture r, g and b to get the color value for this pixel.
    vpi_get_value(r, &value);
    rval = value.value.integer;
    vpi_get_value(g, &value);
    gval = value.value.integer;
    vpi_get_value(b, &value);
    bval = value.value.integer;

    // Scale the values to 8 bits per channel.
    // (We'll lose detail here if the source is >8 bits per channel)
    rval = (rval * 255) / rmax;
    gval = (gval * 255) / gmax;
    bval = (bval * 255) / bmax;

    int phys_x = x + offset_x;
    int phys_y = y + offset_y;

    // If we're in bounds, draw a pixel.
    if (phys_x < width && phys_y < height) {
        SDL_LockSurface(surface);
        uint32_t pixel_value = (
            rval << surface->format->Rshift |
            gval << surface->format->Gshift |
            bval << surface->format->Bshift
        );
        int offset = (phys_y * (surface->pitch / 4)) + phys_x;
        ((uint32_t*)surface->pixels)[offset] = pixel_value;
        SDL_UnlockSurface(surface);
    }

    vpi_get_value(hsync, &value);
    int new_hsync = ! value.value.integer;
    vpi_get_value(vsync, &value);
    int new_vsync = ! value.value.integer;
    x++;
    if (in_hsync && ! new_hsync) {
        if ((x - 1) != line_len) {
            if ((x - 1) > width) {
                vpi_printf(
                    "WARNING: Line length is %i, but was expecting %i\n",
                    x - 1, width
                );
            }
        }
        line_len = x - 1;
        x = 0;
        // Update the screen every lines.
        SDL_UpdateRect(surface, 0, y, width, 1);
        y++;
        if (y < height) {
            clear_rect.y = y;
            SDL_FillRect(
                surface, &clear_rect, SDL_MapRGB(surface->format, 0, 0, 0)
            );
        }
    }
    if (in_vsync && ! new_vsync) {
        SDL_UpdateRect(surface, 0, 0, 0, 0);
        y = 0;
    }
    in_hsync = new_hsync;
    in_vsync = new_vsync;

    // Take an opportunity to poll for events.
    vgasim_events();

    return 0;
}

static int vgasim_init_calltf(char *user_data) {
    if (surface != NULL) {
        vpi_printf("Don't call $vgasimInit more than once\n");
        return 0;
    }

    vpiHandle systfref, args_iter, arg;
    struct t_vpi_value argval;

    systfref = vpi_handle(vpiSysTfCall, NULL);
    args_iter = vpi_iterate(vpiArgument, systfref);

    argval.format = vpiIntVal;

    arg = vpi_scan(args_iter);
    vpi_get_value(arg, &argval);
    width = argval.value.integer;
    arg = vpi_scan(args_iter);
    vpi_get_value(arg, &argval);
    height = argval.value.integer;

    r = vpi_scan(args_iter);
    g = vpi_scan(args_iter);
    b = vpi_scan(args_iter);
    hsync = vpi_scan(args_iter);
    vsync = vpi_scan(args_iter);
    pclk = vpi_scan(args_iter);

    vpi_free_object(args_iter);

    surface = SDL_SetVideoMode(width, height, 32, SDL_SWSURFACE);

    s_cb_data cb_config;
    struct t_vpi_time time;
    time.type = vpiSimTime;
    cb_config.user_data = NULL;
    cb_config.reason = cbValueChange;
    cb_config.cb_rtn = vgasim_pixel_cb;
    cb_config.time = &time;
    cb_config.value = &argval; // borrow this from earlier
    cb_config.obj = pclk;
    vpi_register_cb(&cb_config);
    time.type = vpiSimTime;

    argval.format = vpiObjTypeVal;
    vpi_get_value(r, &argval);

    rmax = 1 << vpi_get(vpiSize, r);
    gmax = 1 << vpi_get(vpiSize, g);
    bmax = 1 << vpi_get(vpiSize, b);

    return 0;
}

void vgasim_register() {
    SDL_Init(SDL_INIT_VIDEO);

    s_vpi_systf_data config;

    config.type = vpiSysTask;
    config.tfname = "$vgasimInit";
    config.calltf = vgasim_init_calltf;
    config.compiletf = NULL;
    config.sizetf = 0;
    config.user_data = 0;
    vpi_register_systf(&config);
}

void (*vlog_startup_routines[])() = {
    vgasim_register,
    0
};
