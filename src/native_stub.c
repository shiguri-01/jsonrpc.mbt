/*
 * Work around a MoonBit native debug test issue where the bundled tcc cannot
 * resolve negative-zero helper symbols. Recheck this when updating the
 * MoonBit toolchain; this file should be removable once tcc handles them.
 */
double __mzerodf = -0.0;
float __mzerosf = -0.0f;
