import imageio

def get_bits(im, y, x):
    b  = format(im[y][x][0], 'b').zfill(8)
    rx = b[0:4]
    b  = format(im[y][x][1], 'b').zfill(8)
    gx = b[0:4]
    b  = format(im[y][x][2], 'b').zfill(8)
    bx = b[0:4]

    return str(rx+gx+bx)

def write_it(name, im, mask=False, rem_x=-1, rem_y=-1):
    if rem_x == -1 or rem_y == -1:
        a = "000000000000"
    else:
        a = get_bits(im, rem_x, rem_y)

    new_file = name.split('.')[0] + ".txt"

    f = open(new_file, 'w')

    y_max, x_max, z = im.shape

    for y in range(y_max):
        for x in range(x_max):
            if(mask == False):
                f.write("\"")
                f.write(get_bits(im, y, x))
                f.write("\"")
                f.write(",\n")
            elif(get_bits(im, y, x) != a):
                f.write("\"")
                f.write(get_bits(im, y, x))
                f.write("\"")
                f.write(",\n")
                
            else:
                f.write("000000000000,\n")
                
    f.close()    

# driver function
def make(name):
    im = imageio.imread(name)
    write_it(name, im)

make("spaceshipBRAM.bmp")