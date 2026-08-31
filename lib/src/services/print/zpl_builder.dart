import 'dart:convert';
import 'dart:typed_data';

/// Ports services/barcodeService.js: age calculator + Zebra ZPL label
/// generator for a 450x250 (dot) patient barcode label.
class ZplBuilder {
  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    final parsed = DateTime.tryParse(v.toString());
    return parsed ?? DateTime.now();
  }

  static String _str(dynamic v) => v == null ? '' : v.toString();

  /// Mirrors calculateAge() from barcodeService.js, including its
  /// "day 0 of next month" trick for borrowing days from the previous month.
  static String calculateAge(dynamic dateOfBirth) {
    final dob = _parseDate(dateOfBirth);
    final now = DateTime.now();

    int years = now.year - dob.year;
    int months = now.month - dob.month;
    int days = now.day - dob.day;

    if (days < 0) {
      months -= 1;
      days += DateTime(now.year, now.month, 0).day; // days in previous month
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }

    years = years < 0 ? 0 : years;
    months = months < 0 ? 0 : months;
    days = days < 0 ? 0 : days;

    return '$years Thn/ $months bln/ $days hr';
  }

  static Uint8List generateZPL(Map<String, dynamic> patientData) {
    final peserta =
        (patientData['peserta'] as Map?)?.cast<String, dynamic>() ?? {};
    final mr = (peserta['mr'] as Map?)?.cast<String, dynamic>() ?? {};

    final noRM = _str(peserta['NORM']).isNotEmpty
        ? _str(peserta['NORM'])
        : _str(mr['noMR']);

    final nama = (_str(peserta['NAMA_LENGKAP']).isNotEmpty
            ? _str(peserta['NAMA_LENGKAP'])
            : _str(peserta['nama']))
        .toUpperCase();

    final genderRaw = _str(peserta['JENIS_KELAMIN']).isNotEmpty
        ? _str(peserta['JENIS_KELAMIN'])
        : _str(peserta['sex']);
    final genderShort =
        RegExp('p', caseSensitive: false).hasMatch(genderRaw) ? 'P' : 'L';

    final dobRaw = peserta['TANGGAL_LAHIR'] ?? peserta['tglLahir'];
    final dob = _parseDate(dobRaw);
    final tglLahir =
        '${dob.day.toString().padLeft(2, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.year}';

    final noKTP = _str(peserta['NIK']).isNotEmpty
        ? _str(peserta['NIK'])
        : (_str(peserta['nik']).isNotEmpty ? _str(peserta['nik']) : '-');

    var alamat = _str(peserta['alamat']);
    if (alamat.length > 50) alamat = alamat.substring(0, 50);

    final umurText = calculateAge(dobRaw);

    final zpl = '^XA\n'
        '^PW450\n'
        '^LL250\n'
        '^LH5,5\n'
        '^FO30,30^A0N,28,28^FD$nama ($genderShort)^FS\n'
        '^FO30,60^A0N,20,20^FDRM : $noRM  Tgl Lhr $tglLahir^FS\n'
        '^FO30,88^A0N,20,20^FDNO KTP : $noKTP^FS\n'
        '^FO30,115^A0N,20,20^FD$umurText^FS\n'
        '^FO30,140^A0N,20,20^FD$alamat^FS\n'
        '^FO30,165^BY2,2,70^BCN,70,N,N,N^FD$noRM^FS\n'
        '^XZ';

    return Uint8List.fromList(utf8.encode(zpl));
  }
}
