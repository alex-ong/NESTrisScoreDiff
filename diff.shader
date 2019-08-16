uniform texture2d numbers;
uniform texture2d arrow;

uniform bool setup_mode = true;
uniform float score1_x1 = 120;
uniform float score1_y1 = 30;
uniform float score1_x2 = 128;
uniform float score1_y2 = 40;

uniform float score2_x1 = 120;
uniform float score2_y1 = 30;

uniform float result_x1 = 120;
uniform float result_y1 = 120;



//we assume that the boxes are equal. they better be...
float block_width() { return (score1_x2 - score1_x1) / 256.0 / 6.0; }
float block_height() { return (score1_y2 - score1_y1) / 224.0; }

float4 score1_box() { return float4(score1_x1 / 256.0, score1_x2 / 256.0, 
                                    score1_y1 / 224.0, score1_y2 / 224.0);}

float4 score2_box() { return float4(score2_x1 / 256.0, score2_x1 / 256.0 + 6*block_width(), 
                                    score2_y1 / 224.0, score2_y1 / 224.0 + block_height());}

float4 result_box() { return float4(result_x1 / 256.0, result_x1 / 256.0 + 6*block_width(), 
									result_y1 / 224.0, result_y1 / 224.0 + block_height());}


float4 escore1_box() 
{
    float4 box = result_box();
    box.r -= block_width();
    box.g += block_width();
    return box;
}


float4 escore1_box_left()
{
    float4 box = result_box();
    box.r -= block_width();
    box.g = box.r+block_width();    
    return box;
}

float4 escore1_box_right()
{
    float4 box = result_box();
    box.r = box.g;
    box.g = box.r+block_width();    
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
    
    if (inBox2(uv, score1_box()))
    {
        return (orig + float4(0,1,0,1)) / 2.0;
    }
	
	if (inBox2(uv, score2_box()))
    {
        return (orig + float4(1,0,1,1)) / 2.0;
    }

	if (inBox2(uv, result_box()))
	{
		return (orig + float4(0,0,1,1)) / 2.0;
	}

    return orig;
}


int getScore(float2 topLeft)
{
	float xInc = block_width();
    float yInc = block_height();
	int result = 0;
	int base = 100000;
    for (int i = 0; i < 6; i++)
    {
        float2 uv2 = float2(topLeft.x + xInc * i, topLeft.y);
        float4 col = image.Sample(textureSampler, uv2);
        if (col.b > 0.5)
        {
            result = -1;
            break;
        }
        result += base * floor(col.r*10 + 0.5);
        base /= 10;
    }
	return result;
}

int getScore1()
{
	float startY = score1_y1/224.0 + block_height() * 0.5f;
    float startX = score1_x1/256.0 + block_width()* 0.5f;
	
	return getScore(float2(startX,startY));

}

int getScore2()
{
	float startY = score2_y1/224.0 + block_height() * 0.5f;
    float startX = score2_x1/256.0 + block_width()* 0.5f;
	
	return getScore(float2(startX,startY));
}



//returns [R,g,b, (success)]
float4 draw_main_split(float2 uv)
{

    int p1 = getScore1();
	int p2 = getScore2();
        
    if (p1 < 0 || p2 < 0)
    {
        return float4(0.0,1.0,0.0,0.0);
    }
    
    int diff = abs(p1-p2);
    int base = 100000;
    
	float4 box = result_box();
	float xInc = block_width();
	
    for (int i = 0; i < 6; i++)
    {
        float4 box2 = box;
        box2.r = box.r + i*xInc;
        box2.g = box2.r + xInc*7/8;        
        int digit = (diff / base) % 10;
        if (inBox2(uv,box2))
        {
            float2 perc = inbox_inverseLerp(uv,box2);
            perc.x /= 10;
            perc.x += (digit * 1/10.0);
            return numbers.Sample(textureSampler,perc);
        } 
        base /= 10;
        
    }

    if (p1 > p2)
    {
        if (inBox2(uv,escore1_box_left()))
        {
            float2 perc = inbox_inverseLerp(uv,escore1_box_left());
            return arrow.Sample(textureSampler,perc);
        }
    } else if (p2 > p1) { //p2 > p1
        if (inBox2(uv,escore1_box_right()))
        {
            float2 perc = inbox_inverseLerp(uv,escore1_box_right());
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
    
	if (inBox2(uv,score1_box()))
	{
		return float4(0.0,0.0,0.0,1.0);
	}
	if (inBox2(uv,score2_box()))
	{
		return float4(0.0,0.0,0.0,1.0);
	}
	
    if (inBox2(uv,escore1_box())) {
        return draw_main_split(uv);       
    }
    return image.Sample(textureSampler,uv);
}
