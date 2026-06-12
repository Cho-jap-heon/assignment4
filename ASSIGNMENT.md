# 컴퓨터구조론 과제 4

이 과제는 5단계 파이프라인 MIPS에서 조기 분기 결정(Early Branch
Resolution)과 데이터 포워딩(Data Forwarding)을 구현하고 시뮬레이션한다.

## 문제 1: Early Branch Resolution

### 명령어 인코딩

| 주소 | Assembly | Hex |
|---:|---|---:|
| `0x00` | `addi $t0, $zero, 10` | `2008000A` |
| `0x04` | `addi $t1, $zero, 5` | `20090005` |
| `0x08` | `bne $t0, $t1, -3` | `1509FFFD` |
| `0x0C` | `addi $t2, $zero, 0x99` | `200A0099` |

I-type 명령어 형식은 `opcode[31:26] | rs[25:21] | rt[20:16] |
immediate[15:0]`이다.

- `$zero=0`, `$t0=8`, `$t1=9`, `$t2=10`
- `addi` opcode는 `001000` (`0x08`)
- `bne` opcode는 `000101` (`0x05`)
- `-3`의 16-bit 2의 보수는 `0xFFFD`

예를 들어 `bne $t0, $t1, -3`은 다음과 같이 구성된다.

```text
opcode   rs($t0) rt($t1) immediate
000101 | 01000 | 01001 | 1111111111111101
= 0x1509FFFD
```

분기 목적지는 현재 분기 명령어의 `PC+4`를 기준으로 계산한다.

```text
0x0C + (sign_extend(0xFFFD) << 2)
= 0x0C + (-3 * 4)
= 0x00
```

### 조기 분기 결정

분기 비교를 EX 단계가 아니라 ID 단계에서 수행하면 잘못 가져온 명령어가
한 개뿐이므로 taken branch의 penalty를 줄일 수 있다.

```verilog
wire bne_D = (instr_D[31:26] == 6'b000101);

assign pc_src_D = branch_D &
                  (bne_D ? (src_a_D != src_b_D)
                         : (src_a_D == src_b_D));
```

`bne`가 ID 단계에 도착했을 때 바로 앞의 `addi $t1`은 EX 단계에 있다.
EX 결과를 ID 비교기로 같은 사이클에 전달할 수 없으므로 hazard unit이 한
사이클 stall하고 bubble을 삽입한다. 다음 사이클에는 MEM/WB 포워딩을 통해
최신 `$t0`, `$t1` 값을 비교한다.

`10 != 5`이므로 분기는 항상 taken이고 IF/ID 레지스터의 canary 명령어가
NOP으로 flush된다. 따라서 `$t2`는 한 번도 `0x00000099`가 되지 않는다.

## 문제 2: Data Forwarding

문제에 두 번째 assembly 목록이 별도로 제시되지 않아 강의 8의 연속 의존성
검증 프로그램을 사용했다.

| 주소 | Assembly | Hex |
|---:|---|---:|
| `0x00` | `addi $t0, $zero, 1` | `20080001` |
| `0x04` | `addi $t1, $zero, 2` | `20090002` |
| `0x08` | `add $t2, $t0, $t1` | `01095020` |
| `0x0C` | `sub $t3, $t1, $t2` | `012A5822` |

R-type 형식은 `opcode | rs | rt | rd | shamt | funct`이다.

```text
add $t2, $t0, $t1
000000 | 01000 | 01001 | 01010 | 00000 | 100000
= 0x01095020

sub $t3, $t1, $t2
000000 | 01001 | 01010 | 01011 | 00000 | 100010
= 0x012A5822
```

### 포워딩 선택

레지스터 파일에 아직 write-back되지 않은 값은 EX/MEM 또는 MEM/WB
파이프라인 레지스터에서 ALU 입력으로 직접 전달한다.

| 선택값 | ALU 입력 데이터 |
|---:|---|
| `2'b00` | ID/EX 레지스터 값 |
| `2'b01` | WB 단계의 `result_W` |
| `2'b10` | MEM 단계의 `alu_result_M` |

MEM 값이 WB 값보다 최신이므로 hazard unit은 MEM 일치를 먼저 검사한다.
또한 destination register가 `$zero`이면 포워딩하지 않는다.

예상 최종 결과:

```text
$t0 = 0x00000001
$t1 = 0x00000002
$t2 = 0x00000003
$t3 = 0xFFFFFFFF
```

## 실행 및 판정

```sh
make
```

테스트벤치는 문제 1에서 `pc_src_D`가 실제로 활성화되는지와 `$t2` canary가
기록되는지를 검사한다. 문제 2에서는 MEM/WB 포워딩 신호와 네 레지스터의
최종 값을 검사한다. 모든 조건이 맞으면 `ALL TESTS PASSED`를 출력한다.
