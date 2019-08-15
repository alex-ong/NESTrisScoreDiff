uniform texture2d block_image;

uniform bool setup_mode = true;
uniform float lines_x1 = 128.50;
uniform float lines_y1 = 57;
uniform float lines_x2 = 133;
uniform float lines_y2 = 64;



float4 line_box() { return float4(lines_x1 / 256.0, lines_x2 / 256.0, 
                                  lines_y1 / 224.0, lines_y2 / 224.0);}
float4 line_box2() { 
    float4 result = line_box();
    float height = (result.a - result.b)* (8.0/7);
    result.b -= 2*height;
    result.a -= 2*height;
    return result;
}

float block_height()
{
    return (lines_y2 - lines_y1) /224.0 * 8.0/7;
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

float score_pixel (float4 raw_box, int row, int col, float2 start_raw, float2 start_ref, float2 raw_pix_size, float2 ref_pix_size)
{
    float4 raw_colour = image.Sample(textureSampler, float2(start_raw.x + col*raw_pix_size.x,
                                                            start_raw.y + row*raw_pix_size.y));           
    float4 ref_colour = block_image.Sample(textureSampler, float2(start_ref.x + col*ref_pix_size.x,
                                                                  start_ref.y + row*ref_pix_size.y));
    return myDiff(raw_colour, ref_colour);                                                                
}

float score_row (float4 raw_box, int row, float2 start_raw, float2 start_ref, float2 raw_pix_size, float2 ref_pix_size)
{
    float result = 0;
    result += score_pixel(raw_box, row, 0,start_raw,start_ref,raw_pix_size,ref_pix_size);        
    result += score_pixel(raw_box, row, 1,start_raw,start_ref,raw_pix_size,ref_pix_size);        
    result += score_pixel(raw_box, row, 2,start_raw,start_ref,raw_pix_size,ref_pix_size);        
    result += score_pixel(raw_box, row, 3,start_raw,start_ref,raw_pix_size,ref_pix_size);        
    result += score_pixel(raw_box, row, 4,start_raw,start_ref,raw_pix_size,ref_pix_size);        
    result += score_pixel(raw_box, row, 5,start_raw,start_ref,raw_pix_size,ref_pix_size);        
    result += score_pixel(raw_box, row, 6,start_raw,start_ref,raw_pix_size,ref_pix_size);  
    return result;
}
//this shit is unrolled. sorry yallah.
float score_number(float4 raw_box, int i)
{
    float result = 0.0;
    int num_pix = 7.0;
    float raw_pix_width = (raw_box.g - raw_box.r)/num_pix;    
    float raw_pix_height = (raw_box.a - raw_box.b)/num_pix;
    float raw_pix_width2 = raw_pix_width/2.0;
    float raw_pix_height2 = raw_pix_height/2.0;
    
    float ref_box_width = 1.0/10;
    float ref_pix_width = ref_box_width / num_pix;    
    float ref_pix_height = 1.0 / num_pix;
    float ref_pix_width2 = ref_pix_width/2.0;
    float ref_pix_height2 = ref_pix_height/2.0;
     
    float start_raw_x = raw_box.r + raw_pix_width2;
    float start_raw_y = raw_box.b + raw_pix_height2;    
    float start_ref_x = ref_box_width*i + ref_pix_width2;
    float start_ref_y = ref_pix_width2;
    
    float2 start_raw = float2(start_raw_x,start_raw_y);
    float2 start_ref = float2(start_ref_x,start_ref_y);
    float2 raw_pix_size = float2(raw_pix_width,raw_pix_height);
    float2 ref_pix_size = float2(ref_pix_width,ref_pix_height);
    
    result += score_row(raw_box,0,start_raw,start_ref,raw_pix_size,ref_pix_size);
    result += score_row(raw_box,1,start_raw,start_ref,raw_pix_size,ref_pix_size);
    result += score_row(raw_box,2,start_raw,start_ref,raw_pix_size,ref_pix_size);
    result += score_row(raw_box,3,start_raw,start_ref,raw_pix_size,ref_pix_size);
    result += score_row(raw_box,4,start_raw,start_ref,raw_pix_size,ref_pix_size);
    result += score_row(raw_box,5,start_raw,start_ref,raw_pix_size,ref_pix_size);
    result += score_row(raw_box,6,start_raw,start_ref,raw_pix_size,ref_pix_size);
    
        
    return result;
    
}

//loop needs to be unrolled to minimise compilation time.
int score_all(float4 raw_box)
{
    int result = 0;
    int min_score = 1000000;
    
    float score;
    score = score_number(raw_box, 0);    
    min_score = score;
    
    
    score = score_number(raw_box, 1);
    if (score < min_score)
    {
        result = 1;
        min_score = score;
    }
    
    score = score_number(raw_box, 2);
    if (score < min_score)
    {
        result = 2;
        min_score = score;
    }
    score = score_number(raw_box, 3);
    if (score < min_score)
    {
        result = 3;
        min_score = score;
    }
    score = score_number(raw_box, 4);
    if (score < min_score)
    {
        result = 4;
        min_score = score;
    }
    score = score_number(raw_box, 5);
    if (score < min_score)
    {
        result = 5;
        min_score = score;
    }
    score = score_number(raw_box, 6);
    if (score < min_score)
    {
        result = 6;
        min_score = score;
    }
    score = score_number(raw_box, 7);
    if (score < min_score)
    {
        result = 7;
        min_score = score;
    }
    score = score_number(raw_box, 8);
    if (score < min_score)
    {
        result = 8;
        min_score = score;
    }
    score = score_number(raw_box, 9);
    if (score < min_score)
    {
        result = 9;
        min_score = score;
    }
    if (min_score > 5)
    {
        return -1;
    }
    return result;
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
    
    int result = score_all(box);       
    if (result < 0)
    {
        return float4(0,0,1,1);
    }
    
    float2 pos = inbox_inverseLerp(uv,box);
    return float4(result / 10.0, 0.0, 0.0, 1.0);
    

}

float4 mainImage(VertData v_in) : TARGET
{
    float2 uv = v_in.uv;
    if (setup_mode) {
        return draw_setup(uv);
    }
    
    if (inBox2(uv, line_box2()))
    {
        uv.y += block_height() * 2;
        return draw_main_split(uv);
        
    }    
    
	return image.Sample(textureSampler, uv);
}
