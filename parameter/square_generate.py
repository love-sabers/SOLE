import os
import math

def generate_lut():
    """Generate LUT for BF16 mantissa squaring with normalization handling"""
    lut_size = 128  # 7-bit mantissa
    lut = []
    
    for i in range(lut_size):
        # Reconstruct BF16 mantissa (with implicit leading 1)
        mantissa_val = 1.0 + i / 128.0
        
        # Calculate square
        squared = mantissa_val * mantissa_val
        
        # Check if normalization is needed (result ≥ 2.0)
        if squared >= 2.0:
            normalized = squared / 2.0
            exp_increment = 1
        else:
            normalized = squared
            exp_increment = 0
        
        # Calculate normalized mantissa fraction (remove leading 1)
        frac_part = normalized - 1.0
        # Convert to 23-bit FP32 mantissa
        mantissa_fp32 = int(frac_part * (2**23))
        
        # Combine into 24-bit LUT entry: [exp_increment(1-bit) | mantissa_fp32(23-bit)]
        lut_entry = (exp_increment << 23) | mantissa_fp32
        lut.append(lut_entry)
    
    return lut

def save_lut_to_file(lut, filename="bf16_square_lut.mem"):
    """Save LUT to file in the same directory as the script"""
    # Get the directory of the current script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(script_dir, filename)
    
    with open(file_path, 'w') as f:
        for entry in lut:
            f.write(f"{entry:06x}\n")  # 24-bit = 6 hex digits
    print(f"LUT saved to {file_path} with {len(lut)} entries")
    return file_path

def verify_lut():
    """Verify LUT correctness"""
    lut = generate_lut()
    errors = 0
    max_error = 0.0
    
    for i in range(128):
        # Calculate theoretical value
        mantissa_val = 1.0 + i / 128.0
        squared = mantissa_val * mantissa_val
        
        # Extract LUT value
        entry = lut[i]
        exp_inc = entry >> 23
        mant_fp32 = entry & 0x7FFFFF
        frac_part = mant_fp32 / (2**23)
        result = (1.0 + frac_part) * (2.0**exp_inc)
        
        # Calculate error
        error = abs(result - squared)
        if error > max_error:
            max_error = error
        
        # Check if error exceeds tolerance (1 ULP)
        if error > 2**-23:  # Allow 1 LSB error
            print(f"Error at index {i}: Input={mantissa_val:.6f}")
            print(f"  Expected: {squared:.8f}, Got: {result:.8f}, Error: {error:.3e}")
            errors += 1
    
    print(f"LUT verification complete. Errors: {errors}, Max error: {max_error:.3e}")
    return errors == 0

if __name__ == "__main__":
    print("Generating BF16 square LUT...")
    lut = generate_lut()
    lut_path = save_lut_to_file(lut)
    
    print("\nVerifying LUT accuracy...")
    if verify_lut():
        print("LUT verification PASSED")
    else:
        print("LUT verification FAILED - check errors above")
    
    print("\nLUT generation complete")