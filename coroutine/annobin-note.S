#ifndef COROUTINE_ANNOBIN_NOTE_DEFINED
# define COROUTINE_ANNOBIN_NOTE_DEFINED 1
  # An annobin note to the assembler sources will stop annocheck from complaining.
  # https://sourceware.org/annobin/annobin.html/Absence-of-compiled-code.html
  .pushsection .gnu.build.attributes, "o", %note, .text
  .balign 4
  .dc.l 2f - 1f   # Size of the name field.
  .dc.l 0         # Empty description field.
  .dc.l 0x100     # This is an OPEN note which applies to all the code in the covered region.
1:
  .dc.b 'G', 'A', # This is a GNU attribute
  .dc.b '*'       # It contains a numeric value
  .dc.b 0x2       # For the -fstack-protector option
  .dc.b 0x3       # The value is 3, which indicated -fstack-protector-strong
  .dc.b 0         # Since this field is nominally a name, it ends with a NUL byte.
2:
  .dc.b 0, 0      # Padding to ensure note ends on a 4 byte boundary.
  .popsection
#endif /* COROUTINE_ANNOBIN_NOTE_DEFINED */
