// Licensed to the .NET Foundation under one or more agreements.
// The .NET Foundation licenses this file to you under the MIT license.

.assembly extern legacy library mscorlib {}
.assembly extern System.Console
{
  .publickeytoken = (B0 3F 5F 7F 11 D5 0A 3A )
  .ver 4:0:0:0
}
.assembly 'b31780' {}
.assembly extern xunit.core {}
.class ILGEN_0xc5f46dbe {

.method static int32 Method_0x3179() {
.maxstack	19

.locals (unsigned int32[] local_0x0,unsigned int16 local_0x3,int16 local_0x4)
 ldc.i4 255
 newarr [mscorlib]System.UInt32 
 stloc local_0x0

Start_Orphan_3:
 ldloc local_0x0
 ldlen
 stloc local_0x3
End_Orphan_3:
Start_Orphan_b:
 ldloc local_0x0
 ldlen
 stloc local_0x4
End_Orphan_b:
ldc.i4 0
ret
}
.method static int32 Main() {
.custom instance void [xunit.core]Xunit.FactAttribute::.ctor() = (
    01 00 00 00
)
.entrypoint
.maxstack	20

call int32 ILGEN_0xc5f46dbe::Method_0x3179()
ldc.i4 100
add
ret
}

}
