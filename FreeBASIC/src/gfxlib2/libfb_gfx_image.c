/*
 *  libgfx2 - FreeBASIC's alternative gfx library
 *	Copyright (C) 2005 Angelo Mottola (a.mottola@libero.it)
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

/*
 * image.c -- image create/destroy functions
 *
 * chng: jan/2005 written [lillo]
 *
 */

#include "fb_gfx.h"


/*:::::*/
FBCALL void *fb_GfxImageCreate(int width, int height, unsigned int color, int depth, int flags)
{
	FB_GFXCTX *context = fb_hGetContext();
	PUT_HEADER *image;
	int size, pitch, header_size = 4;
	int bpp = __fb_gfx->bpp;
	
	if ((!__fb_gfx) || (width <= 0) || (height <= 0))
		return NULL;
	
	if (depth > 0) {
		bpp = BYTES_PER_PIXEL(depth);
		if ((bpp != 1) && (bpp != 2) && (bpp != 4))
			return NULL;
	}
	
	if (flags & DEFAULT_COLOR_1) {
		switch (bpp) {
			case 1: color = 0; break;
			case 2: color = MASK_COLOR_16; break;
			case 4: color = MASK_COLOR_32 | MASK_A_32; break;
		}
	}
	else {
		if (bpp == 2)
			color = ((color & 0xF8) >> 3) | ((color & 0xFC00) >> 5) | ((color & 0xF80000) >> 8);
	}
	
	pitch = width * bpp;
	if (!(__fb_gfx->flags & QB_COMPATIBILITY)) {
		header_size = sizeof(PUT_HEADER);
		pitch = (pitch + 0xF) & ~0xF;
	}
	size = pitch * height;
	
	image = (PUT_HEADER *)malloc(size + header_size);
	if (__fb_gfx->flags & QB_COMPATIBILITY) {
		/* use old-style header for compatibility */
		image->old.bpp = bpp;
		image->old.width = width;
		image->old.height = height;
	}
	else {
		image->type = PUT_HEADER_NEW;
		image->bpp = bpp;
		image->width = width;
		image->height = height;
		image->pitch = pitch;
		fb_hMemSet(image->_reserved, 0, sizeof(image->_reserved));
	}
	fb_hPrepareTarget(context, (void *)image, MASK_A_32);
	context->pixel_set((unsigned char *)image + header_size, color, (pitch * height) / bpp);
	
	return image;
}


/*:::::*/
FBCALL void fb_GfxImageDestroy(void *image)
{
	free(image);
}
