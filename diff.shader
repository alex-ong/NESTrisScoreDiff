uniform texture2d block_image;
uniform texture2d arrow;

uniform bool setup_mode = true;
uniform float lines_x1 = 120;
uniform float lines_y1 = 30;
uniform float lines_x2 = 128;
uniform float lines_y2 = 40;


float4 line_box() { return float4(lines_x1 / 256.0, lines_x2 / 256.0, 
                                  lines_y1 / 224.0, lines_y2 / 224.0);}


float block_width() { return (lines_x2 - lines_x1) / 256.0 / 6.0; }
float block_height() { return (lines_y2 - lines_y1) / 224.0 / 2.0; }


float4 eline_box() 
{
    float4 box = line_box();
    box.r -= block_width();
    box.g += block_width();
    return box;
}


float4 eline_box_left()
{
    float4 box = line_box();
    box.r -= block_width();
    box.g = box.r+block_width();
    box.b = box.b + 0.5*block_height();
    box.a = box.b+block_height();
    return box;
}

float4 eline_box_right()
{
    float4 box = line_box();
    box.r = box.g;
    box.g = box.r+block_width();
    box.b = box.b + 0.5*block_height();
    box.a = box.b+block_height();
    return box;
}


bool inBox2(float2 uv, float4 box)
{
	return (uv.x >= box.r && 
			uv.x <= box.g && 
			uv.y >= box.b && 
			uv.y <= box.a);
}
float inverseLerp(float start, float end, float val)
{
    return (val - start) / (end - start);
}

float2 inbox_inverseLerp(float2 uv, float4 box)
{
    return float2(inverseLerp(box.r,box.g, uv.x),
                  inverseLerp(box.b,box.a, uv.y));
}


float2 inbox_lerp(float2 perc, float4 box)
{
    return float2 (lerp(box.r,box.g,perc.x),
                   lerp(box.b,box.a,perc.y));
}


float myDiff(float4 a, float4 b)
{
    return (a.r - b.r) * (a.r - b.r);
}



float4 draw_setup(float2 uv)
{    
    float4 orig = image.Sample(textureSampler, uv);
    
    if (inBox2(uv, line_box()))
    {
        return (orig + float4(1,1,1,1)) / 2.0;
    }

    return orig;
}


//returns [R,g,b, (success)]
float4 draw_main_split(float2 uv)
{
        
    float4 box = line_box();

    float xInc = block_width();
    float yInc = block_height();
    
    int p1 = 0;
    int p2 = 0;
    
    float startY = lines_y1/224.0 + yInc * 0.5f;
    float startX = lines_x1/256.0 + xInc * 0.5f;
    int base = 100000;
    for (int i = 0; i < 6; i++)
    {
        float2 uv2 = float2(startX + xInc * i, startY);
        float4 col = image.Sample(textureSampler, uv2);
        if (col.b > 0.5)
        {
            p1 = -1;
            break;
        }
        p1 += base * floor(col.r*10 + 0.5);
        base /= 10;
    }
    
    base = 100000;
    startY += yInc;
    for (int i = 0; i < 6; i++)
    {
        float2 uv2 = float2(startX + xInc * i, startY);
        float4 col = image.Sample(textureSampler, uv2);
        
        if (col.b > 0.5)
        {
            p2 = -1;
            break;
        }
        int digit = base * round(col.r*10);
        
        p2 += digit;
        base /= 10;
    }
    
    if (p1 < 0 || p2 < 0)
    {
        return float4(0.0,1.0,0.0,0.0);
    }
    
    int diff = abs(p1-p2);
    base = 100000;
    
    for (int i = 0; i < 6; i++)
    {
        float4 box2 = box;
        box2.r = box.r + i*xInc;
        box2.g = box2.r + xInc*7/8;
        box2.b += yInc*0.5f;
        box2.a = box2.b + yInc;
        int digit = (diff / base) % 10;
        if (inBox2(uv,box2))
        {
            float2 perc = inbox_inverseLerp(uv,box2);
            perc.x /= 10;
            perc.x += (digit * 1/10.0);
            return block_image.Sample(textureSampler,perc);
        } 
        base /= 10;
        
    }


    if (p1 > p2)
    {
        if (inBox2(uv,eline_box_left()))
        {
            float2 perc = inbox_inverseLerp(uv,eline_box_left());
            return arrow.Sample(textureSampler,perc);
        }
    } else { //p2 > p1
        if (inBox2(uv,eline_box_right()))
        {
            float2 perc = inbox_inverseLerp(uv,eline_box_right());
            perc.x = 1.0 - perc.x;
            return arrow.Sample(textureSampler,perc);
        }
    }

    return float4(0.0,0.0,0.0,0.0);    
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    if (setup_mode) {
        return draw_setup(uv);
    }
    
    if (inBox2(uv,eline_box())) {
        return draw_main_split(uv);       
    }
    return image.Sample(textureSampler,uv);
}
