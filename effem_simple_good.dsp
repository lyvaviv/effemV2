import ("stdfaust.lib");

declare name "Effem";
declare author "Vivien Aubke";
declare copyright "lyva.me";
declare license "GPL 3";

declare options "[midi:on]";
declare nvoices "16";

// Synth Modules

// misc UI elements
pi_slide = hslider("h:Oscillator 1/PI slide[style:knob]", 3.14159265359, 2, 4, 0.0000001);
mute = *(1-checkbox("h:osc3/mute osc 3"));

// carrier oscillator
phasor(f) = f/ma.SR : (+, 1 : fmod)~_;
gain_osc1 = hslider("h:Oscillator 1/Osc1 Level", 0, 0, 1, 0.01);

sin1_process = (button("gate") * phasor(hslider("freq", 200,50,1000,0.01) + phasor2(mod_freq) * index)) * (pi_slide*2) : sin * gain_osc1 : _;
sin1_process2 = (button("gate") * phasor(hslider("freq", 200,50,1000,0.01)) * (pi_slide*2)) * sin2_process : sin * gain_osc1 : _;

sin1_select = nentry("h:Oscillator 1/FM/AM Switch (Osc 1 only)", 0, 0, 1, 1), sin1_process, sin1_process2 : select2;

// modulator oscillator
phasor2(f) = f/ma.SR : (+, 1 : fmod)~_;

gain_osc2 = hslider("h:Modulator (Osc2)/Modulator Level", 0, 0, 1, 0.01);
mod_freq = hslider("h:Modulator (Osc2)/Modulator Frequency[style:knob]", 550, 0.1, 2000, 0.01);
index = hslider("h:Modulator (Osc2)/Modulation Index", 100, 0, 1000, 0.01);

sin2_process = phasor2(mod_freq) * (ma.PI*2) : sin * gain_osc2 :> _;



// noise channel
random = +(12345) ~ *(1103515245);
noise = random/2147483647.0;

noise_process = (noise * hslider("h:mix/Noise", 0, 0, 0.05, 0.0001)) :> _;

// pitch envelope oscillator
triangle(N, f0) = (8.0 / ma.PI ^ 2.0) * sum(i, N, cos(ph * h(i)) / h(i) ^ 2.0)
    with {
        h(i) = 2 * i + 1;
        ph = os.phasor(2.0 * ma.PI, f0);
    };

square(N, f0) = (4.0 / ma.PI) * sum(i, N, sin(ph * h(i)) / h(i))
    with {
        h(i) = 2 * i + 1;
        ph = os.phasor(2.0 * ma.PI, f0);
    };



bubble(f0,trig) = nentry("h:osc3/Sin/Tri/Sqr/Saw", 0, 0, 3, 1), osc_sin, osc_tri, osc_sq, osc_saw : ba.selectn(4) : * (exp(-damp*time) : si.smooth(atk1))
	with {

  		osc_sin = os.osc(f) + (os.osc(f*2)*0.5) + (os.osc(f*3)*0.25) + (os.osc(f*4)*0.125);
		osc_tri = triangle(20, f);	  
		osc_sq = square(20, f);
		osc_saw = os.sawtooth(f);
		damp = sus1*f0 + 0.0014*f0^(3/2);
		f = f0*(1+sigma*time);
		sigma = eta * damp;
		eta = dec1;
		time = 0 : (select2(trig>trig'):+(1)) ~ _ : ba.samp2sec;
	};

pitch_envelope = vgroup("h:osc3/Pitch Envelope", en.adsr(atk, dec, sus, 0));

		atk1 = vslider("h:osc3/[1]Osc3 Attack", 0.99, 0, 0.99, 0.001);
		dec1 = vslider("h:osc3/[0]Decay P.Env", 0.001, 0, 1, 0.001);
		sus1 = vslider("h:osc3/[2]Osc3 Sustain", 0.043, -0.034, 0.65, 0.001);

pitch_process = button("gate") : bubble(hslider("h:osc3/freq", 600, 150, 2000, 1)) : mute : _;
pitch_process2 = button("gate") : bubble(modFreq) : mute : _;

lfoFreq2 = hslider("h:osc3/Osc3Freq LFO Freq[style:knob]", 10, 0.1, 20, 0.01);
lfoDepth2 = hslider("h:osc3/Osc3Freq LFO Depth[style:knob]", 0, 0, 1000, 1);
modFreq = 0 + os.osc(lfoFreq2) * lfoDepth2 : max(30);

// processing chain and effects

	// filter
subtractive = hgroup("[1]Filter", fi.resonlp(resFreq, q, 1))
	with {
  		ctFreq = hslider("[0]Cutoff Frequency[style:knob]", 10000, 50, 10000, 0.1);
		q = hslider("[1]Q[style:knob]", 1, 1, 30, 0.1);
		lfoFreq = hslider("[2]LFO Frequency[style:knob]", 10, 0.1, 20, 0.01);
		lfoDepth = hslider("[3]LFO depth[style:knob]", 0, 0, 1000, 1);
		resFreq = ctFreq + os.osc(lfoFreq) * lfoDepth : max(30);
	};

	// drive
drywet(fx) = _ <: _, fx : *(1-w) , *(w) :> _
	with {
 	 	w = vslider("h:mix/Drive[style:knob]", 0.1, 0, 1, 0.01);
	};

driveSlider = hslider("h:mix/Drive Compensate[style:knob]", 1, 0, 1, 0.01);
drive = *(107) : min(1) : max(-1) *(driveSlider);

	// envelope
envelope = hgroup("[1]Envelope", en.adsr(attack, decay, sustain, release, gate) * gain * 0.3)
	with {
		attack = hslider("[0]Attack[style:knob]",0.1, 0.001, 1, 0.001);
		decay = hslider("[1]Decay[style:knob]",0.1, 0.001, 1, 0.001);
		sustain = hslider("[2]Sustain[style:knob]",0.98, 0.01, 1, 0.001);
  		release = hslider("[3]Release[style:knob]",0.1, 0.001, 1, 0.001);
  		gain = hslider("[4]gain[style:knob]", 1, 0, 1, 0.01);
  		gate = button("[5]gate");
	};

    // Reverb
viv_env_rev = environment {

    diffuser_aux(angle, g, scale1, scale2, size, block) = si.bus(2) <: ((si.bus(2):par(i,2,*(c_norm))
        : ((si.bus(4) :> si.bus(2)
            : block
            : rotator(angle)
            : (de.fdelay1a(8192, prime_delays(size*scale1):smooth_init(0.9999,prime_delays(size*scale1)) -1),
               de.fdelay1a(8192, prime_delays(size*scale2):smooth_init(0.9999,prime_delays(size*scale2)) -1)))
        ~ par(i,2,*(-s_norm))) : par(i,2,mem:*(c_norm)))
        ,
        par(i,2,*(s_norm)))
        :> si.bus(2)
        with {
            rotator(angle) = si.bus(2) <: (*(c),*(-s),*(s),*(c)) :(+,+) : si.bus(2)
            with {
                c = cos(angle);
                s = sin(angle);
            };
            c_norm = cos(g);
            s_norm = sin(g);
        };

    diffuser(angle, g, scale1, scale2, size) = diffuser_aux(angle,g,scale1,scale2,size,si.bus(2));


    diffuser_nested(1, angle, g, scale, size) = diffuser_aux(angle,g,scale,scale+10,size,si.bus(2));
    diffuser_nested(N, angle, g, scale, size) = diffuser_aux(angle,g,scale,scale+10,size,diffuser_nested(N-1,angle,g,scale+13,size));

    prime_delays(x) = (waveform {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499, 503, 509, 521, 523, 541, 547, 557, 563, 569, 571, 577, 587, 593, 599, 601, 607, 613, 617, 619, 631, 641, 643, 647, 653, 659, 661, 673, 677, 683, 691, 701, 709, 719, 727, 733, 739, 743, 751, 757, 761, 769, 773, 787, 797, 809, 811, 821, 823, 827, 829, 839, 853, 857, 859, 863, 877, 881, 883, 887, 907, 911, 919, 929, 937, 941, 947, 953, 967, 971, 977, 983, 991, 997, 1009, 1013, 1019, 1021, 1031, 1033, 1039, 1049, 1051, 1061, 1063, 1069, 1087, 1091, 1093, 1097, 1103, 1109, 1117, 1123, 1129, 1151, 1153, 1163, 1171, 1181, 1187, 1193, 1201, 1213, 1217, 1223, 1229, 1231, 1237, 1249, 1259, 1277, 1279, 1283, 1289, 1291, 1297, 1301, 1303, 1307, 1319, 1321, 1327, 1361, 1367, 1373, 1381, 1399, 1409, 1423, 1427, 1429, 1433, 1439, 1447, 1451, 1453, 1459, 1471, 1481, 1483, 1487, 1489, 1493, 1499, 1511, 1523, 1531, 1543, 1549, 1553, 1559, 1567, 1571, 1579, 1583, 1597, 1601, 1607, 1609, 1613, 1619, 1621, 1627, 1637, 1657, 1663, 1667, 1669, 1693, 1697, 1699, 1709, 1721, 1723, 1733, 1741, 1747, 1753, 1759, 1777, 1783, 1787, 1789, 1801, 1811, 1823, 1831, 1847, 1861, 1867, 1871, 1873, 1877, 1879, 1889, 1901, 1907, 1913, 1931, 1933, 1949, 1951, 1973, 1979, 1987, 1993, 1997, 1999, 2003, 2011, 2017, 2027, 2029, 2039, 2053, 2063, 2069, 2081, 2083, 2087, 2089, 2099, 2111, 2113, 2129, 2131, 2137, 2141, 2143, 2153, 2161, 2179, 2203, 2207, 2213, 2221, 2237, 2239, 2243, 2251, 2267, 2269, 2273, 2281, 2287, 2293, 2297, 2309, 2311, 2333, 2339, 2341, 2347, 2351, 2357, 2371, 2377, 2381, 2383, 2389, 2393, 2399, 2411, 2417, 2423, 2437, 2441, 2447, 2459, 2467, 2473, 2477, 2503, 2521, 2531, 2539, 2543, 2549, 2551, 2557, 2579, 2591, 2593, 2609, 2617, 2621, 2633, 2647, 2657, 2659, 2663, 2671, 2677, 2683, 2687, 2689, 2693, 2699, 2707, 2711, 2713, 2719, 2729, 2731, 2741, 2749, 2753, 2767, 2777, 2789, 2791, 2797, 2801, 2803, 2819, 2833, 2837, 2843, 2851, 2857, 2861, 2879, 2887, 2897, 2903, 2909, 2917, 2927, 2939, 2953, 2957, 2963, 2969, 2971, 2999, 3001, 3011, 3019, 3023, 3037, 3041, 3049, 3061, 3067, 3079, 3083, 3089, 3109, 3119, 3121, 3137, 3163, 3167, 3169, 3181, 3187, 3191, 3203, 3209, 3217, 3221, 3229, 3251, 3253, 3257, 3259, 3271, 3299, 3301, 3307, 3313, 3319, 3323, 3329, 3331, 3343, 3347, 3359, 3361, 3371, 3373, 3389, 3391, 3407, 3413, 3433, 3449, 3457, 3461, 3463, 3467, 3469, 3491, 3499, 3511, 3517, 3527, 3529, 3533, 3539, 3541, 3547, 3557, 3559, 3571, 3581, 3583, 3593, 3607, 3613, 3617, 3623, 3631, 3637, 3643, 3659, 3671, 3673, 3677, 3691, 3697, 3701, 3709, 3719, 3727, 3733, 3739, 3761, 3767, 3769, 3779, 3793, 3797, 3803, 3821, 3823, 3833, 3847, 3851, 3853, 3863, 3877, 3881, 3889, 3907, 3911, 3917, 3919, 3923, 3929, 3931, 3943, 3947, 3967, 3989, 4001, 4003, 4007, 4013, 4019, 4021, 4027, 4049, 4051, 4057, 4073, 4079, 4091, 4093, 4099, 4111, 4127, 4129, 4133, 4139, 4153, 4157, 4159, 4177, 4201, 4211, 4217, 4219, 4229, 4231, 4241, 4243, 4253, 4259, 4261, 4271, 4273, 4283, 4289, 4297, 4327, 4337, 4339, 4349, 4357, 4363, 4373, 4391, 4397, 4409, 4421, 4423, 4441, 4447, 4451, 4457, 4463, 4481, 4483, 4493, 4507, 4513, 4517, 4519, 4523, 4547, 4549, 4561, 4567, 4583, 4591, 4597, 4603, 4621, 4637, 4639, 4643, 4649, 4651, 4657, 4663, 4673, 4679, 4691, 4703, 4721, 4723, 4729, 4733, 4751, 4759, 4783, 4787, 4789, 4793, 4799, 4801, 4813, 4817, 4831, 4861, 4871, 4877, 4889, 4903, 4909, 4919, 4931, 4933, 4937, 4943, 4951, 4957, 4967, 4969, 4973, 4987, 4993, 4999, 5003, 5009, 5011, 5021, 5023, 5039, 5051, 5059, 5077, 5081, 5087, 5099, 5101, 5107, 5113, 5119, 5147, 5153, 5167, 5171, 5179, 5189, 5197, 5209, 5227, 5231, 5233, 5237, 5261, 5273, 5279, 5281, 5297, 5303, 5309, 5323, 5333, 5347, 5351, 5381, 5387, 5393, 5399, 5407, 5413, 5417, 5419, 5431, 5437, 5441, 5443, 5449, 5471, 5477, 5479, 5483, 5501, 5503, 5507, 5519, 5521, 5527, 5531, 5557, 5563, 5569, 5573, 5581, 5591, 5623, 5639, 5641, 5647, 5651, 5653, 5657, 5659, 5669, 5683, 5689, 5693, 5701, 5711, 5717, 5737, 5741, 5743, 5749, 5779, 5783, 5791, 5801, 5807, 5813, 5821, 5827, 5839, 5843, 5849, 5851, 5857, 5861, 5867, 5869, 5879, 5881, 5897, 5903, 5923, 5927, 5939, 5953, 5981, 5987, 6007, 6011, 6029, 6037, 6043, 6047, 6053, 6067, 6073, 6079, 6089, 6091, 6101, 6113, 6121, 6131, 6133, 6143, 6151, 6163, 6173, 6197, 6199, 6203, 6211, 6217, 6221, 6229, 6247, 6257, 6263, 6269, 6271, 6277, 6287, 6299, 6301, 6311, 6317, 6323, 6329, 6337, 6343, 6353, 6359, 6361, 6367, 6373, 6379, 6389, 6397, 6421, 6427, 6449, 6451, 6469, 6473, 6481, 6491, 6521, 6529, 6547, 6551, 6553, 6563, 6569, 6571, 6577, 6581, 6599, 6607, 6619, 6637, 6653, 6659, 6661, 6673, 6679, 6689, 6691, 6701, 6703, 6709, 6719, 6733, 6737, 6761, 6763, 6779, 6781, 6791, 6793, 6803, 6823, 6827, 6829, 6833, 6841, 6857, 6863, 6869, 6871, 6883, 6899, 6907, 6911, 6917, 6947, 6949, 6959, 6961, 6967, 6971, 6977, 6983, 6991, 6997, 7001, 7013, 7019, 7027, 7039, 7043, 7057, 7069, 7079, 7103, 7109, 7121, 7127, 7129, 7151, 7159, 7177, 7187, 7193, 7207, 7211, 7213, 7219, 7229, 7237, 7243, 7247, 7253, 7283, 7297, 7307, 7309, 7321, 7331, 7333, 7349, 7351, 7369, 7393, 7411, 7417, 7433, 7451, 7457, 7459, 7477, 7481, 7487, 7489, 7499, 7507, 7517, 7523, 7529, 7537, 7541, 7547, 7549, 7559, 7561, 7573, 7577, 7583, 7589, 7591, 7603, 7607, 7621, 7639, 7643, 7649, 7669, 7673, 7681, 7687, 7691, 7699, 7703, 7717, 7723, 7727, 7741, 7753, 7757, 7759, 7789, 7793, 7817, 7823, 7829, 7841, 7853, 7867, 7873, 7877, 7879, 7883, 7901, 7907, 7919, 7927, 7933, 7937, 7949, 7951, 7963, 7993, 8009, 8011, 8017, 8039, 8053, 8059, 8069, 8081, 8087, 8089, 8093, 8101, 8111, 8117, 8123, 8147, 8161, 8167, 8171, 8179, 8191, 8209, 8219, 8221, 8231, 8233, 8237, 8243, 8263, 8269, 8273, 8287, 8291, 8293, 8297, 8311, 8317, 8329, 8353, 8363, 8369, 8377, 8387, 8389, 8419, 8423, 8429, 8431, 8443, 8447, 8461, 8467, 8501, 8513, 8521, 8527, 8537, 8539, 8543, 8563, 8573, 8581, 8597, 8599, 8609, 8623, 8627, 8629, 8641, 8647, 8663, 8669, 8677, 8681, 8689, 8693, 8699, 8707, 8713, 8719, 8731, 8737, 8741, 8747, 8753, 8761, 8779, 8783, 8803, 8807, 8819, 8821, 8831, 8837, 8839, 8849, 8861, 8863, 8867, 8887, 8893, 8923, 8929, 8933, 8941, 8951, 8963, 8969, 8971, 8999, 9001, 9007, 9011, 9013, 9029, 9041, 9043, 9049, 9059, 9067, 9091, 9103, 9109, 9127, 9133, 9137, 9151, 9157, 9161, 9173, 9181, 9187, 9199, 9203, 9209, 9221, 9227, 9239, 9241, 9257, 9277, 9281, 9283, 9293, 9311, 9319, 9323, 9337, 9341, 9343, 9349, 9371, 9377, 9391, 9397, 9403, 9413, 9419, 9421, 9431, 9433, 9437, 9439, 9461, 9463, 9467, 9473, 9479, 9491, 9497, 9511, 9521, 9533, 9539, 9547, 9551, 9587, 9601, 9613, 9619, 9623, 9629, 9631, 9643, 9649, 9661, 9677, 9679, 9689, 9697, 9719, 9721, 9733, 9739, 9743, 9749, 9767, 9769, 9781, 9787, 9791, 9803, 9811, 9817, 9829, 9833, 9839, 9851, 9857, 9859, 9871, 9883, 9887, 9901, 9907, 9923, 9929, 9931, 9941, 9949, 9967, 9973, 10007, 10009, 10037, 10039, 10061, 10067, 10069, 10079, 10091, 10093, 10099, 10103, 10111, 10133, 10139, 10141, 10151, 10159, 10163, 10169, 10177, 10181, 10193, 10211, 10223, 10243, 10247, 10253, 10259, 10267, 10271, 10273, 10289, 10301, 10303, 10313, 10321, 10331, 10333, 10337, 10343, 10357, 10369, 10391, 10399, 10427, 10429, 10433, 10453, 10457, 10459, 10463, 10477, 10487, 10499, 10501, 10513, 10529, 10531, 10559, 10567, 10589, 10597, 10601, 10607, 10613, 10627, 10631, 10639, 10651, 10657, 10663, 10667}, int(x)) : rdtable;

    smooth_init(s,default) = *(1.0 - s) : + ~ (+(default*init(1)):*(s)) with { init(value) = value - value'; };

    viverb(dt, damp, size, early_diff, feedback, mod_depth, mod_freq)
        = (si.bus(4) :> seq(i,3,diffuser_nested(4,ma.PI/2,(-1^i)*diff,10+19*i,size))
            : par(i,2,si.smooth(damp_interp)))
        ~((de.fdelay4(512, 10 + depth + depth*os.oscrc(freq)),de.fdelay4(512, 10 + depth + depth*os.oscrs(freq)))
            : (de.sdelay(65536,44100/2,floor(dt_constrained)),de.sdelay(65536,44100/2,floor(dt_constrained)))
            : par(i,2,*(fb)))
        with {
            fb = feedback:linear_interp;
            depth = ((ma.SR/44100)*50*mod_depth):linear_interp;
            freq = mod_freq:linear_interp;
            diff = early_diff:linear_interp;
            dt_constrained = min(65533,ma.SR*dt);
            damp_interp = damp:linear_interp;
            linear_interp(x) = (x+x')/2;
        };

};

viverb(dt, damp, size, early_diff, feedback, mod_depth, mod_freq) 
	= viv_env_rev.viverb(dt, damp, size, early_diff, feedback, mod_depth, mod_freq);

viverb_comp = viverb(dt, damp, size, early_diff, feedback, mod_depth, mod_freq)
with {

    rev_group(x) = vgroup("[0] Viverb",x);
    
    mix_group(x) = rev_group(hgroup("[0] Mix",x));
    dt = mix_group(hslider("[01]delayTime [style:knob]", 0.2, 0.001, 1.45, 0.0001));
    damp = mix_group(hslider("[02]damping [style:knob]", 0, 0, 0.99, 0.001));
    size = mix_group(hslider("[03]size [style:knob]", 1, 0.5, 3, 0.0001));
    early_diff = mix_group(hslider("[04]diffusion [style:knob]", 0.5, 0, 0.99, 0.0001));
    feedback = mix_group(hslider("[05]feedback [style:knob]", 0.5, 0, 1, 0.01));
    
    mod_group(x) = rev_group(hgroup("[1] Mod",x));
    mod_depth = mod_group(hslider("[06]modDepth [style:knob]", 0.1, 0, 1, 0.001));
    mod_freq = mod_group(hslider("[07]modFreq [style:knob]", 2, 0, 10, 0.01));
};

viverb_drywet = out(wetGain, dryGain)
     with {
        wetAmount = vslider("v:Viverb/DryWet [style:knob]", 0.1, 0, 1, 0.01);

        fx = viverb_comp;
        N = inputs(fx);
        wet(wg) = fx : par(i, N, *(wg));
        dry(dg) = par(i, N, *(dg));
        out(wg, dg) = si.bus(N) <: wet(wg), dry(dg) :> si.bus(N);

        theta = ma.PI*wetAmount/2.;
        dryGain = cos(theta)/sqrt(2.);
        wetGain = sin(theta)/sqrt(2.);

    };


process = (envelope * (sin1_select + noise_process + (nentry("h:osc3/Enable Freq Modulation", 0, 0, 1, 1), pitch_process, pitch_process2 : select2)) :> _) * hslider("h:mix/Master",0.7, 0, 1, 0.01) : drywet(drive) : subtractive <: viverb_drywet;