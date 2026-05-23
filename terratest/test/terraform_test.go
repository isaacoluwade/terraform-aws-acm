package test

import (
	"fmt"
	"os"
	"testing"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/acm"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestACMCertIssued is the canonical happy-path Terratest. It applies the
// module against a real Route 53 zone, asserts the cert reaches ISSUED via
// the AWS API, then destroys.
//
// Requires a pre-created Route 53 public zone in a test domain:
//   TEST_ROUTE53_ZONE_ID
//   TEST_ROUTE53_ZONE_NAME
//
// Skips when the fixture is not set so local runs don't block on missing
// infrastructure.
func TestACMCertIssued(t *testing.T) {
	t.Parallel()

	zoneID := os.Getenv("TEST_ROUTE53_ZONE_ID")
	zoneName := os.Getenv("TEST_ROUTE53_ZONE_NAME")
	if zoneID == "" || zoneName == "" {
		t.Skip("TEST_ROUTE53_ZONE_ID / TEST_ROUTE53_ZONE_NAME not set; skipping")
	}

	envName := fmt.Sprintf("ci-%s", random.UniqueId())
	region := "us-east-1"
	domain := fmt.Sprintf("tt-%s.%s", envName, zoneName)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../plan",
		Vars: map[string]interface{}{
			"project":          "tt",
			"environment":      envName,
			"region":           region,
			"public_zone_id":   zoneID,
			"public_zone_name": zoneName,
			"domain_name":      domain,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// aws_acm_certificate_validation blocks the apply until the cert is ISSUED.
	// Verify that contract holds by hitting the AWS API directly.
	certArns := terraform.OutputMap(t, terraformOptions, "certificate_arns")
	certArn := certArns["main"]
	require.NotEmpty(t, certArn, "certificate_arns[main] output should be populated")

	sess := session.Must(session.NewSession(&aws.Config{Region: aws.String(region)}))
	acmClient := acm.New(sess)
	out, err := acmClient.DescribeCertificate(&acm.DescribeCertificateInput{
		CertificateArn: aws.String(certArn),
	})
	require.NoError(t, err)
	assert.Equal(t, "ISSUED", *out.Certificate.Status, "cert must be ISSUED after apply")
	assert.Equal(t, "DNS", *out.Certificate.DomainValidationOptions[0].ValidationMethod)
}
