#!/usr/bin/env python3
"""Render the Chinese Booth lesson from project figures and macOS speech."""
from __future__ import annotations
import argparse
import os
import time
import re
import shutil
import subprocess
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'video'
FONT = '/System/Library/Fonts/STHeiti Medium.ttc'
SCENES = [
    ('01 开场', '一个乘积，几种硬件走法',
     ['从 Booth 1951 原论文出发', '手算 13 × (−7)，再看 RTL 和真实波形', '最后讨论何时值得替换普通乘法器'],
     'assets/architecture.png',
     '这段视频带你从一九五一年 Booth 的原论文，走到可以运行的 Verilog 工程。我们会先弄清编码为什么成立，再用十三乘负七跟踪硬件的每一步。之后比较八种有符号架构，并说明它们和普通乘法器数值相同的条件，以及性能结论的边界。'),
    ('02 原论文', 'Booth 的核心观察：连续的 1',
     ['原文目标：正数和负数用统一过程相乘', '一串 1 可以用两端的加、减表示', '原文没有提出本工程的 radix-4/8、CSA 或流水线'],
     'video/paper_page1.png',
     '这是 A D Booth 一九五一年论文的第一页。那时带符号乘法常需要额外的符号判断与校正。他观察到，乘数中连续的一串二进制一，可以改成区间两端的一次加和一次减。例如二进制零零一一一一零零，等于零一零零零零零零减零零零零零一零零。论文提出的是相邻位决策；后来的高基数编码和流水线不属于这篇原文。'),
    ('03 四种决策', '比较当前位与右邻位',
     ['00、11：部分和不变', '01：加被乘数 M', '10：减被乘数 M', '然后算术右移；原文高端最后一步不移位'],
     'video/paper_page3.png',
     '请看原文第三页。Booth 从乘数的最低有效位开始，比较当前位与右边已经处理过的邻位。零零和一一只移位，零一先加被乘数，一零先减被乘数。注意这里的位顺序：若把邻位看反，加减号也会反。原文还规定最高端最后一步不右移。本工程用整数寄存器实现同一相邻位思想，因此循环形式和原文的定点小数记法不同。'),
    ('04 代数证明', '为什么乘积保持不变？',
     ['定义 q[-1] = 0；d[i] = q[i-1] - q[i]', 'sum(d[i] * 2^i) = signed_W(q)', '相邻项相消；符号位保留负权重'],
     None,
     '对工程中的 W 位二补码整数，额外定义右边界位为零。每位的 Booth 数字等于右邻位减当前位。把所有数字乘以相应的二的幂再相加，中间项会两两消去，最后剩下低位的正权重和符号位的负权重，正是原来的有符号整数。再整体乘以被乘数，结果当然相同。这是现代整数形式的推导，不是把论文中的定点公式逐字照搬。'),
    ('05 手算', '例子：13 × (−7) = −91',
     ['W = 8：13 = 00001101，−7 = 11111001', 'radix-2 非零项：−13 + 26 − 104 = −91', '边界事件代替逐位处理连续的 1'],
     'assets/radix4_13x-7.png',
     '现在用十三乘负七。八位二补码中，负七写成一一一一一零零一。按相邻位公式，非零 Booth 数字出现在第零位、第一位和第三位，对应负十三、正二十六和负一百零四，合计负九十一。右侧图还展示了 radix 四的分组部分积；分组数变少，但它只是另一种等值表示。你可以运行工程中的 recode 脚本逐项核对。'),
    ('06 radix-2 RTL', 'A / Q / Q−1 迭代数据通路',
     ['Q[0] 与 Q−1 控制 A 加、减或保持', 'A、Q、Q−1 合并后做算术右移', 'A 与 M 增加保护位；W 次处理后输出 2W 位'],
     'assets/architecture.png',
     '看经典 radix 二迭代模块。Q 寄存器保存正在处理的乘数，Q 减一保存上一位，A 保存部分和。每拍根据 Q 的最低位和 Q 减一，选择加 M、减 M 或保持，再把整个合并状态做算术右移。算术右移必须保留符号。工程还给 A 和 M 增加一位保护位，防止最小负数相关的中间值溢出。经过 W 次处理，取完整的二 W 位乘积。'),
    ('07 真实波形', '从 VCD 看 13 × (−7)',
     ['start 接受输入；busy 表示正在迭代', '观察 Q[0]、Q−1、A 与 done 的时序', 'radix-2/4/8 完成周期不同，结果均为 −91'],
     'assets/waveform_13x-7.png',
     '这张图由仿真的 V C D 文件生成，不是示意波形。输入被接受后，三个迭代实现分别推进自己的寄存器。请重点看 Q 的最低位、Q 减一、部分和 A 以及 done 脉冲。位宽为八时，本工程的 radix 二需要八个忙周期，radix 四需要四个，radix 八需要三个。它们完成时间不同，但输出的完整二补码乘积都等于负九十一。'),
    ('08 架构选择', 'radix-4/8、CSA 与流水线',
     ['radix-4 每组两位；radix-8 每组三位并需 3M', '并行行可用线性加法或 CSA 压缩', '流水版可每拍接受一组，延迟与吞吐须分开看'],
     'assets/pipeline_13x-7.png',
     '改进型 radix 四一次处理两位，radix 八一次处理三位，所以理论部分积行数减少。不过 radix 八需要产生三倍被乘数，译码也更复杂。并行部分积可以串接加法器，也可以先用进位保存压缩树，最后做一次进位传播加法。流水版又加入寄存器，使连续输入每拍可以进入一组。部分积行数、单笔延迟和持续吞吐量是三个不同指标，不能混在一起比较。'),
    ('09 性能边界', '能否替代普通乘法器？',
     ['同宽度、同 signed 解释、完整 2W 位：数值相同', '接口周期不同，不能直接互换', '面积、频率、功耗必须在目标器件上测量'],
     'assets/synth_w16.png',
     '什么时候能替代普通乘法器？若两输入位宽与带符号解释相同，并保留完整的二 W 位结果，Booth 和普通乘法实现相同的整数乘法。但组合输出、迭代握手和流水时序不同，系统接口必须同步调整。右侧是工程在指定 Yosys 通用映射条件下的统计，不能当成真实芯片的面积或频率。尤其在 FPGA 上，行为级乘号可能直接推断出硬件 D S P 块，手写 Booth 未必更好。'),
    ('10 radix-4 分组', '三位窗口生成一个编码数字',
     ['窗口取 q[2i+1]、q[2i]、q[2i−1]', '编码数字可为 0、±1、±2', '−7 的非零行：+13 与 −104'],
     'assets/radix4_13x-7.png',
     '现在把 radix 四算得更具体。每组实际查看三个重叠的位：本组两位，加上前一组的最高位。三位窗口译码为零、正负一或正负二，再乘以被乘数和相应的四的幂。负七这个例子中，第一组零一零得到正一，产生正十三；第二组一零零得到负二，左移两位后是负一百零四。其余组为零，相加仍是负九十一。注意 radix 四的两行不等于 radix 二那三个边界项逐项相同；只有总和必须一致。'),
    ('11 边界输入', '最小负数为什么要保护位？',
     ['W=8：+128 超出 8 位有符号范围', '中间加减要扩位，最终保留完整 16 位', '工程有 −128 × −1 的 VCD 与测试'],
     'assets/waveform_minx-1.png',
     '带符号实现最容易出错的是最小负数。八位二补码能表示负一百二十八，却不能表示正一百二十八。如果在八位范围内先求它的相反数，就会溢出。工程的 radix 二迭代版本把被乘数与部分和扩出一个保护位，并在最终保留十六位乘积。右侧真实波形来自负一百二十八乘负一，其正确答案是正一百二十八。检查这类边界输入，比只看普通正数例子更能发现位宽问题。'),
    ('12 公平比较', '少几行，不等于硅面积一定更小',
     ['译码、3M、CSA、布线和寄存器也要资源', 'Yosys 通用映射仅是特定工具实验', 'FPGA 的 * 可能映射专用 DSP 块'],
     'assets/synth_w16.png',
     '最后说性能判断。radix 四和 radix 八确实减少理论部分积行数，但更复杂的译码、三倍数生成、压缩树、布线和寄存器都可能抵消收益。本工程用 Yosys 做了同流程的通用门统计，让你有可复现的观察，不过它不是某个真实工艺的面积、频率或功耗。特别是在 FPGA 上，直接写乘号可能被综合到专用 D S P 乘法块。公平比较必须固定位宽、目标器件、寄存器边界、时钟约束和 D S P 使用策略，然后看布局布线后的报告。'),
    ('13 验证与结尾', '自己跑一遍，再读代码',
     ['bash scripts/run.sh：仿真等价与 VCD', 'bash scripts/lint.sh：Verilator 参数展开', 'docs/08：原论文；docs/01–07：推导、架构与验证'],
     None,
     '最后给出学习路径。先打开原论文精读，看清一九五一年真正提出的相邻位规则；再按第一章手算编码，阅读 radix 二迭代 RTL，运行仿真并对照波形。工程还提供不同位宽的等价测试、形式验证和通用综合记录。请把数值正确、周期行为和实际 P P A 分开验证。到这里，你已经能从公式走到寄存器，再从波形回到原理。'),
]


def ffmpeg_path():
    found = shutil.which('ffmpeg')
    if found: return found
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError as exc:
        raise SystemExit('Install imageio-ffmpeg or ffmpeg first') from exc


def wrap(draw, text, font, max_width):
    lines=[]; current=''
    for c in text:
        if draw.textbbox((0,0), current+c, font=font)[2] > max_width and current:
            lines.append(current); current=c
        else: current+=c
    if current: lines.append(current)
    return lines


def slide(scene, index, output):
    label,title,bullets,source,_=scene
    im=Image.new('RGB',(1280,720),'#0b1324'); d=ImageDraw.Draw(im)
    font_title=ImageFont.truetype(FONT,43); font_body=ImageFont.truetype(FONT,28)
    font_small=ImageFont.truetype(FONT,19); font_label=ImageFont.truetype(FONT,22)
    d.rounded_rectangle((40,33,1240,98),radius=18,fill='#13233d')
    d.text((65,50),label,font=font_label,fill='#74e0d0')
    d.text((65,125),title,font=font_title,fill='white')
    has_img=source is not None
    text_w=570 if has_img else 1070
    y=235
    for b in bullets:
        lines=wrap(d,b,font_body,text_w-40)
        d.ellipse((67,y+11,79,y+23),fill='#54d3b6')
        for line in lines:
            d.text((95,y),line,font=font_body,fill='#e0e9f7')
            y+=43
        y+=30
    if has_img:
        src=Image.open(ROOT/source).convert('RGB')
        max_w,max_h=560,440
        src.thumbnail((max_w,max_h),Image.Resampling.LANCZOS)
        box=Image.new('RGB',(max_w+16,max_h+16),'#e8eef8')
        box.paste(src,((box.width-src.width)//2,(box.height-src.height)//2))
        im.paste(box,(650,205))
    d.line((65,671,1215,671),fill='#3b5575',width=2)
    d.text((65,680),'Booth 编码教学工程 · 原论文 / RTL / 仿真 / 验证',font=font_small,fill='#9eb2ca')
    d.text((1150,680),f'{index:02d}/{len(SCENES):02d}',font=font_small,fill='#9eb2ca')
    im.save(output)


def check_slide_glyphs():
    from fontTools.ttLib import TTCollection
    supported = TTCollection(FONT).fonts[0].getBestCmap()
    shown = set(''.join(str(item) for scene in SCENES for item in (scene[0], scene[1], *scene[2])))
    missing = sorted(c for c in shown if ord(c) not in supported)
    if missing:
        raise SystemExit(f'Font is missing slide glyphs: {missing}')

def main():
    check_slide_glyphs()
    ap=argparse.ArgumentParser(); ap.add_argument('--engine',choices=['edge','mac'],default='edge')
    ap.add_argument('--voice',default='Tingting');ap.add_argument('--rate',type=int,default=145)
    ap.add_argument('--edge-voice',default='zh-CN-XiaoxiaoNeural')
    ap.add_argument('--edge-rate',default='-8%');ap.add_argument('--edge-pitch',default='-2Hz')
    args=ap.parse_args(); OUT.mkdir(exist_ok=True); frames=OUT/'frames'; audio=OUT/'audio';frames.mkdir(exist_ok=True);audio.mkdir(exist_ok=True)
    voice_desc=(f'在线中文神经语音 {args.edge_voice}，语速 {args.edge_rate}' if args.engine=='edge' else f'macOS {args.voice}')
    md=['# Booth 编码视频讲解词','',f'配音：{voice_desc}；画面由工程图、原论文扫描页和脚本生成。','']
    durations=[]
    for idx,sc in enumerate(SCENES,1):
        label,title,bullets,source,narration=sc
        slide(sc,idx,frames/f'{idx:02d}.png')
        (audio/f'{idx:02d}.txt').write_text(narration,encoding='utf-8')
        aiff=audio/f'{idx:02d}.aiff'
        if args.engine=='edge':
            mp3=audio/f'{idx:02d}.mp3'
            command=[sys.executable,'-m','edge_tts','--voice',args.edge_voice,
                     '--rate='+args.edge_rate,'--pitch='+args.edge_pitch,
                     '--text',narration,'--write-media',str(mp3)]
            for attempt in range(3):
                if mp3.exists(): mp3.unlink()
                result=subprocess.run(command,capture_output=True,text=True)
                if result.returncode==0 and mp3.is_file() and mp3.stat().st_size>1000:break
                if attempt==2:raise RuntimeError(f'Online voice failed at scene {idx}: {result.stderr[-700:]}')
                time.sleep(2**attempt)
            if aiff.exists(): aiff.unlink()
            subprocess.run(['afconvert',str(mp3),str(aiff),'-f','AIFF','-d','BEI16@24000'],check=True)
        else:
            subprocess.run(['say','-v',args.voice,'-r',str(args.rate),'-f',str(audio/f'{idx:02d}.txt'),'-o',str(aiff)],check=True)
        probe=subprocess.run(['afinfo',str(aiff)],capture_output=True,text=True,check=True)
        m=re.search(r'estimated duration: (\d+\.\d+)',probe.stdout)
        if not m: raise RuntimeError(f'Cannot read duration for slide {idx}: {probe.stdout[-500:]}')
        dur=float(m[1]);durations.append(dur)
        md.extend([f'## {label}：{title}','',narration,'','画面要点：'+'；'.join(bullets),''])
    (OUT/'讲解词.md').write_text('\n'.join(md),encoding='utf-8')
    def esc(p): return str(p.resolve()).replace("'", "'\\''")
    frame_lines=[];audio_lines=[]
    for idx,dur in enumerate(durations,1):
        frame_lines.extend([f"file '{esc(frames/f'{idx:02d}.png')}'",f'duration {dur:.3f}'])
        audio_lines.append(f"file '{esc(audio/f'{idx:02d}.aiff')}'")
    frame_lines.append(f"file '{esc(frames/f'{len(SCENES):02d}.png')}'")
    (OUT/'frames.ffconcat').write_text('\n'.join(frame_lines)+'\n')
    (OUT/'audio.ffconcat').write_text('\n'.join(audio_lines)+'\n')
    target=OUT/'Booth编码原理与硬件实现_中文讲解.mp4'
    if sys.platform == 'darwin':
        subprocess.run(['swift',str(ROOT/'scripts/render_video.swift')],cwd=ROOT,check=True)
        stereo=OUT/'Booth编码讲解音频.m4a'
        subprocess.run(['afconvert',str(target),str(stereo),'-f','m4af',
                        '-d','aac@44100','-c','2','-b','128000'],check=True)
        subprocess.run(['swift',str(ROOT/'scripts/remux_video_audio.swift')],cwd=ROOT,check=True)
        os.replace(OUT/'Booth编码原理与硬件实现_双声道.mp4',target)
        shutil.copy2(target, OUT/'Booth编码原理与硬件实现_晓晓女声有声版.mp4')
        print(target);print(f'Duration estimate: {sum(durations):.1f} seconds')
        return
    ff=ffmpeg_path()
    cmd=[ff,'-y','-f','concat','-safe','0','-i',str(OUT/'frames.ffconcat'),'-f','concat','-safe','0','-i',str(OUT/'audio.ffconcat'),'-map','0:v:0','-map','1:a:0','-c:v','libx264','-preset','medium','-tune','stillimage','-pix_fmt','yuv420p','-vf','fps=24','-c:a','aac','-b:a','160k','-af','apad','-shortest','-movflags','+faststart',str(target)]
    subprocess.run(cmd,check=True)
    print(target);print(f'Duration estimate: {sum(durations):.1f} seconds')

if __name__=='__main__':main()
